#!/bin/bash

render_json_template() {
  eval "echo \"$(cat $1 | sed 's/"/\\"/g')\""
}

APISERVER=https://${KUBERNETES_SERVICE_HOST}
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
TOKEN=$(cat ${SERVICEACCOUNT}/token)
CACERT=${SERVICEACCOUNT}/ca.crt


curl -k ${APISERVER} &>/dev/null || exit 1

nodes_config=$(curl --silent --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/nodes | \
               jq -r '.items[] | { "cidr": .spec.podCIDR, "ip": .status.addresses[] | select(.type=="InternalIP") | .address }' 2>/dev/null)
nodes_ips=$(echo $nodes_config | jq -r '.ip')

for ip in $nodes_ips; do
        iface=$(ip -br a show up | awk /"${ip}"/'{print $1}')
        if [[ -n "${iface}" ]]; then
                cidr=$(echo $nodes_config | jq -r ". | select(.ip==\"${ip}\") | .cidr")
                break
        fi
done

if [[ -z "$iface" ]]; then
        echo "Failed to fetch the interface"
        exit 1
fi

if [[ -z "$cidr" ]]; then
        echo "Failed to fetch the CIDR"
        exit 1
fi

# Masquerade all trafic to the internet

nft 'add chain nat POD-MASQ { type nat hook postrouting priority 100 ; }'
nft 'flush chain nat POD-MASQ'
cidrs=$(echo $nodes_config | jq -s '.' | jq -r 'map(.cidr) | join(",")')
nft add rule nat POD-MASQ ip daddr != \{ ${cidrs} \} oifname "${iface}" masquerade

# Install the plugin

render_json_template ./bash-cni.conf > /host/etc/cni/net.d/bash-cni.conf
cp ./bash-cni /host/opt/cni/bin/
chmod +x /host/opt/cni/bin/bash-cni

# Configure the FRR

cp ./daemons /etc/frr/daemons

cat >/etc/frr/ospfd.conf <<EOF
access-list k8s remark Advertise only my CIDR
access-list k8s permit 127.0.0.1/32
access-list k8s permit ${cidr}
!
router ospf
passive-interface default
redistribute kernel
distribute-list k8s out kernel
!
interface ${iface}
ip ospf authentication
ip ospf authentication-key ${AUTHENTICATION_KEY}
ip ospf area 0
no ip ospf passive
EOF

exit 0