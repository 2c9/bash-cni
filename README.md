# bash-cni

At this moment I'm learning how kubernetes networking functioning, especially cni plugins like calico, so I decided to write my own simple plugin in bash to figure out how they work.

K8s was installed with kubeadm and its version is {Major:"1", Minor:"26", GitVersion:"v1.26.0" }.

The main goals of start up script (initContainer):
1. Connecting to k8s API
2. Getting PodCIDRs and finding the host's interface name
3. Configuring NAT rules
4. Installing the cni plugin
5. Configuring ospf in frr

My lab environment looks like that:

![Lab env](/assets/images/lab.png "Lab env")