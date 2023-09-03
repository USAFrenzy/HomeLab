
# References Used
- [computingforgeeks.com](https://computingforgeeks.com/install-kubernetes-cluster-on-debian-12-bookworm/?expand_article=1)
- [kubernetes.io](https://kubernetes.io/docs/)
- [docs.tigera.io](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)
- [```containerd``` Getting Started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)

____________________________________________________________________


<br><br>

____________________________________________________________________

#### <center>NOTE:<br>This Guide Is For Specifically Installing Kubernetes On Debian 12 (Bookworm) Instead Of Ubuntu Server (For Which There Are Numerous Guides For).<br>Debian 12 Was Chosen For The QoL Updates Over Debian 11 And The Usage Of Less System Resources Overall Compared To Ubuntu Server.</center>

____________________________________________________________________


<br>

____________________________________________________________________
#### <center>NOTE:<br>As Of August 31 2023, The Google Kubernetes Repository Has Been Officially Deprecated, As Such, This Guide Uses The Community-Owned Repository Instead.<br>This Is Another Facet That Is Different From Most Other Guides To Kubernetes Installations Out There As They All Mostly Default To Using Google's Repository.<br>* The ```pkgs.k8s.io``` repository replaces both the ```apt.kubernetes.io``` and ```yum.kubernetes.io``` repositories.</center>

____________________________________________________________________

<br>

____________________________________________________________________

#### <center>NOTE:<br>This Kubernetes Installation Guide Uses ```containerd``` As The Container Runtime And ```calico``` As The Network Plugin.<br>* ```calico``` is used for its expansive, customizable, advanced feature set and its inherent data encryption.<br>* ```containerd``` is used for its lightweight, advanced feature set, and low resource nature.</center>

____________________________________________________________________


<br><br><br>

____________________________________________________________________

# <center>Part One: Common Installation Steps That Track Across All Nodes (Control Node(s) And Any Worker Nodes)</center>


<br>

## 1) Checking Node Hosts
- Ensure each node has a unique hostname
  - This can be checked by running ```cat /etc/hostname```
- Ensure each node has a unique MAC address
  - This can be checked by running "```ip link```" or "```ifconfig -a```"
- Ensure each node has a unique product_uuid
  - This can be checked by running "```sudo cat /sys/class/dmi/id/product_uuid```"

<br>

## 2) Disabling Swap
- This can be done by running "```sudo swappoff -a```" (this temporarily disables swap until a reboot occurs)
- To make this permanent, run "```sudo nano /etc/fstab```" and comment out the line that holds any swap info
  - Note: This may not be necessary depending on the machine configuration

<br>

## 3) Ensure The Necessary Ports For This Installation Are Open
- This can be accomplished by checking the below ports with netcat by running "```nc <ip_address> <port>```"

| Node Type             | Port(s)     | Protocol | Traffic Flow          | Service                                        |
|-----------------------|-------------|----------|---------------------- |------------------------------------------------|
| Control               | 6443        | TCP      | INBOUND               | Kubernetes API Server                          |
| Control               | 2379-2380   | TCP      | INBOUND               | etcd Server Client API                         |
| Control               | 10250       | TCP      | INBOUND               | Kubelet API                                    |
| Control               | 10257       | TCP      | INBOUND               | kube-controller-manager                        |
| Control               | 10259       | TCP      | INBOUND               | kube-scheduler                                 |
| Worker                | 10250       | TCP      | INBOUND               | Kubelet API                                    |
| Worker                | 30000-32767 | TCP      | INBOUND               | Default Range For NodePort Services            |
| ALL                   | 179         | TCP      | BIDIRECTIONAL         | Calico Networking With BGP Enabled             |
| ALL                   | 4789        | UDP      | BIDIRECTIONAL         | Calico Networking With VXLAN Enabled           |
| ALL                   | 4789        | UDP      | BIDIRECTIONAL         | Calico Networking With Flannel (VXLAN) Enabled |
| Any Typha Agent Hosts | 5473        | TCP      | INBOUND               | Calico Networking With Typha Agents Enabled    |
| ALL                   | 51820-51821 | UDP      | BIDIRECTIONAL         | Calico Networking With WireGuard Enabled       |


<br>

## 4) Next, Make Sure Everything Is Up To Date And Refresh Package Repositories
- Run "```sudo apt update```"
- Run "```sudo apt full-upgrade -y```"
- Run "```sudo apt install curl gpg gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates -y```"

<br>

## 5) Forwarding IPv4 And Allowing IP Tables See Bridged Traffic
- Run "```cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf overlay br_netfilter EOF```"
- Run "```sudo modprobe overlay```"
- Run "```sudo modprobe br_netfilter```"
- Run "```cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf net.bridge.bridge-nf-call-iptables  = 1 net.bridge.bridge-nf-call-ip6tables = 1 net.ipv4.ip_forward = 1 EOF```"
- Next Run "```sudo sysctl --system```" to apply the sysctl parameters without needing to reboot
- Verify that both the br_netfilter and overlay modules have been loaded by running:
  - "```lsmod | grep br_netfilter```"
  - "```lsmod | grep overlay```"
-  Verify that the following variables are set to ```1``` by running "```sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward```"
   -  net.bridge.bridge-nf-call-iptables
   -  net.bridge.bridge-nf-call-ip6tables
   -  net.ipv4.ip_forward
-
## 6) Ensuring ```cgroupv2``` Is Enabled
- kubernetes v1.28 defaults to using ```systemd``` as the ```cgroup``` driver
  - With this knowledge, we're going to take advantage of ```cgroupv2``` instead of either ```systemd``` or ```cgroupfs``` since Debian 12 also supports and defaults to ```cgroupv2```
    - The reason for this is because ```cgroupv2``` requires the ```systemd``` driver anyways and is objectively better
- To double check and ensure that ```cgroupv2``` is enabled on Debian 12, run "```stat -fc %T /sys/fs/cgroup/```" which should result in ```cgroup2fs```
  - If for whatever reason, the result isn't ```cgroup2fs``` (for example, the result would be ```tmpfs``` for ```cgroupfs```):
    - Run "```sudo nano /etc/default/grub```"
    - Add the following line under ```GRUB_CMDLINE_LINUX```:  "```systemd.unified_cgroup_hierarchy=1```"
    - Run "```sudo update-grub```"
    - Run "```reboot``` to apply the setting change

<br>


## 7) Installing And Configuring ```kubeadm``` (Unfinished - Researching was out of order)
- [placeholder]
- We also need to ensure that the ```KubeletConfiguration``` is using the ```systemd``` driver
  - Run "```sudo nano /var/lib/kubelet/config.yaml```"
  -   Locate and set:<br>```kind: KubeletConfiguration```<br>```apiVersion: kubelet.config.k8s.io/v1beta1```<br>```cgroupDriver: "systemd"```

<br>

## 8) Installing The ```containerd``` Runtime
- We are going to be using the latest version of ```containerd``` (v1.7.5 as of writing)
  - Release versions and the next two steps are found over at [containerd.io/downloads](https://containerd.io/downloads/)
- Run "```wget https://github.com/containerd/containerd/releases/download/v1.7.5/containerd-1.7.5-linux-amd64.tar.gz```"
- Run "```tar xvf containerd-1.7.5-linux-amd64.tar.gz```
- If the directory doesn't already exist yet, run "```sudo mkdir -p /etc/containerd```"
- Now run "```containerd config default | sudo tee /etc/containerd/config.toml```"
- Since we are using the ```cgroupv2``` option, we need to make sure ```containerd``` is also using the ```systemd``` driver
  - Run "```sudo nano /etc/containerd/config.toml```"
  - Locate And Set:<br>```[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]```<br>```...```<br>```[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]```<br>```SystemdCgroup = true```
- Run "```sudo systemctl restart containerd```"
- Run "```sudo systemctl enable containerd```"
- To verify that ```containerd``` is now running, run "```systemctl status containerd```"
