
# References Used
- [computingforgeeks.com](https://computingforgeeks.com/install-kubernetes-cluster-on-debian-12-bookworm/?expand_article=1)
- [kubernetes.io](https://kubernetes.io/docs/)
- [docs.tigera.io](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)
- [```containerd``` Getting Started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
- [server-world.info](https://www.server-world.info/en/note?os=Debian_12&p=kubernetes&f=1)

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
- This can be done by running "```sudo swapoff -a```" (this temporarily disables swap until a reboot occurs)
- To verify that swap has been disabled, run "``` free -h```
  - The swap line should read:  ```Swap:             0B          0B          0B```
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
- Run "```sudo apt install -y curl gpg gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates```"
- Run "```sudo apt full-upgrade -y```"

<br>

# <center> NOW, THE STEPS ARE ABOUT TO FORK HERE.</center>

## I WOULD STILL LIKE TO GET THE CGROUPV2 WORKING, HOWEVER, I'M RUNNING INTO ISSUES AT THE MOMENT WITH IT, SO, INSTEAD WE'RE GOING TO FORK INTO FIRST GOING OVER THE METHOD THAT WORKED FOR ME AND THEN THE WORK IN PROGRESS METHOD BELOW THAT.

<br>

____________________________________________________________________

# <center> Method That Has Worked </center>

____________________________________________________________________

## 5) Setting Up ```containerd``` And Networking
- Run "```sudo apt install -y containerd iptables```" (This is in addition to what was run in step 4 above)
- Configure the networking by running:
  -  "```cat > /etc/sysctl.d/99-k8s-cri.conf <<EOF```"
  -  "```net.bridge.bridge-nf-call-iptables=1```"
  -  "```net.bridge.bridge-nf-call-ip6tables=1```"
  -  "```net.ipv4.ip_forward=1```"
  -  "```EOF```"
- Apply the changes by running "```sysctl --system```"

<br>

## 6) Enabling The Modules
- Run "```modprobe overlay```"
- Run "```modprobe br_netfilter```"
- Run "```echo -e overlay\\nbr_netfilter > /etc/modules-load.d/k8s.conf```"
- Run "```update-alternatives --config iptables```"
  - Enter ```1```

<br>

## 7) Swapping to CgroupV1
- Run "```sudo nano /etc/default/grub```"
  - Add  "```systemd.unified_cgroup_hierarchy=0```" To The Line That Contains ```GRUB_CMDLINE_LINUX```
    - I.E. --> "```GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0"```"
- Run "```update-grub```"
- Run "```reboot```

<br>

## 8) Installing Kubernetes (This is the portion that uses the community-owned repo now that the others have been deprecated )
- Run "```curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg```"
- Run "```echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list```"
- Run "```sudo apt update```"
- Run "```sudo apt install -y kubelet kubeadm kubectl```"
- Run "```sudo apt-mark hold kubelet kubeadm kubectl```"
- Run "```ln -s /opt/cni/bin /usr/lib/cni```"

<br>

## 9) Configuring Control Plane
- Run "```kubeadm init --control-plane-endpoint=<your_master_cluster_endpoint_or_single_controller_ip> --pod-network-cidr=<your_pod_network/16> --cri-socket=unix:///run/containerd/containerd.sock```"
  - Make note of and save the tokens and hash value generated for you here as they are used in the next step
- Run "```mkdir -p $HOME/.kube```"
- Run "```cp -i /etc/kubernetes/admin.conf $HOME/.kube/config```"
- Run "```chown $(id -u):$(id -g) $HOME/.kube/config```"
- Run "```wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml```" (This is for the Calico networking plugin)
- Run "```kubectl apply -f calico.yaml```"
- Run "```kubectl get nodes```" -> Stop here until ```STATUS``` says ```Ready```
- Run "```kubectl get pods -A```" -> Stop here until ```STATUS``` says ```Running``` for all pods

<br>

## 10) Configuring Worker Nodes
- Run "```kubeadm join <endpoint_used_in_init_cmd>:6443 --token <your_genereated_token> --discovery-token-ca-cert-hash sha256:<your_generated_hash>```
- Run "```kubectl get nodes```" and wait until ```STATUS``` reads ```Ready``` for all nodes
- And That's It!

<br>

____________________________________________________________________

# <center> Method That Is Still A Work In Progress </center>

____________________________________________________________________


## 5) Forwarding IPv4 And Allowing IP Tables See Bridged Traffic
- Run "```cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf```"
  - Next Run "```overlay```"
  - Next Run "```br_netfilter```"
  - Lastly, Run "```EOF```"
- Run "```sudo modprobe overlay```"
- Run "```sudo modprobe br_netfilter```"
- Run "```cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf```"
  - Next Run "```net.bridge.bridge-nf-call-iptables=1```
  - Next Run "```net.bridge.bridge-nf-call-ip6tables=1```
  - Next Run "```net.ipv4.ip_forward=1```"
  - Lastly, Run "```EOF```"
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

## 7) Installing The ```containerd``` Runtime
- We are going to be using the latest version of ```containerd``` (v1.7.5 as of writing)
  - Release versions and the next two steps are found over at [containerd.io/downloads](https://containerd.io/downloads/)
- Run "```sudo wget https://github.com/containerd/containerd/releases/download/v1.7.5/containerd-1.7.5-linux-amd64.tar.gz```"
- Run "```sudo tar Cxzf /usr/local/ containerd-1.7.5-linux-amd64.tar.gz```
- Now we need to download the ```systemd``` service for ```containerd``` as we are using ```systemd``` driver
  - Run "```sudo wget -P /usr/local.lib/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service```"
  - Run "```sudo systemctl daemon-reload```"
  - Run "```sudo systemctl enable --now containerd```
- Now we need to download ```runc```
  - Run "```sudo wget -P /usr/local/sbin/runc -m 755 https://github.com/opencontainers/runc/releases/```"
  - Run "```sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"```"
    - Hit ```Enter``` when prompted
  -


- Run "```curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/debian.gpg```"
- Run "```sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"```"
- Run "```sudo apt update```"
- Run "```sudo apt install -y containerd.io```



- If the directory doesn't already exist yet, run "```sudo mkdir -p /etc/containerd```"
- Now run "```containerd config default | sudo tee /etc/containerd/config.toml```"
- Since we are using the ```cgroupv2``` option, we need to make sure ```containerd``` is also using the ```systemd``` driver
  - Run "```sudo nano /etc/containerd/config.toml```"
  - Locate And Set: (Line 137)<br>"```[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]```<br>```...```<br>```[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]```<br>```SystemdCgroup = true```"
- Run "```sudo systemctl restart containerd```"
- Run "```sudo systemctl enable containerd```"
- To verify that ```containerd``` is now running, run "```systemctl status containerd```"

<br>

## 8) Installing And Configuring ```kubeadm```, ```kubelet```, and ```kubectl```
- [placeholder]
- To download the public signing key, run "```curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg```"
- To add the repository, run "```echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list```"
- Now, we should update the package index and install kubelet, kubeadm, and kubectl. The hold command is used to pin their versions.
  - Run "```sudo apt-get update```"
  - Run "```sudo apt-get install -y kubelet kubeadm kubectl```"
  - Run "```sudo apt-mark hold kubelet kubeadm kubectl```"
- To verify the installation of ```kubeadm``` and ```kubectl```, run "```kubectl version --client && kubeadm version```"


- We also need to ensure that the ```KubeletConfiguration``` is using the ```systemd``` driver for ```cgroupv2``` to work
  - Run "```sudo nano /var/lib/kubelet/config.yaml```"
  - Locate and set:<br>"```kind: KubeletConfiguration```<br>```apiVersion: kubelet.config.k8s.io/v1beta1```<br>```cgroupDriver: "systemd"```"
    - NOTE: As of kubernetes v1.21, ```systemd``` should be the default value that is set here

<br>
