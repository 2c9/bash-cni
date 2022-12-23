# bash-cni

At this moment I'm learning how kubernetes networking functioning, especially cni plugins like calico, so I decided to write my own simple plugin in bash to figure out how they work.

Versions:
1. Ubuntu 22.04.1 LTS (jammy)
2. K8s was installed with kubeadm and its version is {Major:"1", Minor:"26", GitVersion:"v1.26.0" }.

Installation steps:

```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd.io 

sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF
sudo sysctl --system

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo -s
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
exit

sudo kubeadm config images pull
```

Control plane:
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Other nodes:
```bash
sudo kubeadm join 172.16.97.75:6443 --token a...b --discovery-token-ca-cert-hash sha256:a...b
```


The main goals of [start up script](https://github.com/2c9/bash-cni/blob/main/cni/cni-startup.sh) (initContainer):
1. Connecting to k8s API
2. Getting PodCIDRs and finding the host's interface name
3. Configuring NAT rules
4. Installing the cni plugin
5. Configuring ospf in frr

The main goals of [bash-cni](https://github.com/2c9/bash-cni/blob/main/cni/bash-cni):
1. Getting IP address for a pod using host-local plugin
2. Creating a veth pair
3. Configuring the network in the pod's namespace
4. Adding a route in the host's namespace to the pod via the veth interface

My lab environment looks like that:

![Lab env](/assets/images/lab.png "Lab env")