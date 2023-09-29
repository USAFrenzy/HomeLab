
# References Used
- [github.com/kubernetes - Load Balancing Options](https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#options-for-software-load-balancing)
- [kubesphere.io - Load Balancer Setup](https://www.kubesphere.io/docs/v3.3/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/)
- [kubernetes.io - HA Cluster Setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- [docs.tigera.io - For Ports Used By Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)
- [server-world.info - For Individual Node Setup](https://www.server-world.info/en/note?os=Debian_12&p=kubernetes&f=1)

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

## 5) Setup Local DNS Entries On Each Host (Ran Into Several Issues When This Step Was Omitted)
- Run "```nano /etc/hosts/```" on each master node, worker node, and load balancer node
- In each node's ```hosts``` file:
  - Add every other node's local DNS entry and their IP address
- For example, this setup uses the following for the master nodes:
  - ```192.168.3.9  k8s-master-01```
  - ```192.168.3.10 k8s-master-02```
  - ```192.168.3.11 k8s-master-03```
  - Therefore, the ```hosts``` file of each and every node will also include those entries
  - This is necessary to allow the cluster to resolve host names and addresses
- Next, since this lab's setup uses ```cloud-init```, we need to modify another file to keep the cloud config from overwriting these additions
- Run "```nano /etc/cloud/cloud.cfg```"
  - Comment out "```update_etc_hosts```"
  - Add "```manage_etc_hosts: false```"
  - Save and exit the file and then reboot.
  - Ensure the newly added host entries weren't overridden by running "```cat /etc/hosts/```"

<br>

### NOTE: Step 6 Applies To All Nodes Being Configured In The Load Balancer Cluster Setup

<br>

## 6) Configuring The Load Balancer Nodes (For this setup, there are two VMs acting as the load balancer nodes)
- Install both ```keepalived``` and ```haproxy``` by running "```apt install keepalived haproxy psmisc -y```"
- Run "```nano /etc/haproxy/haproxy.cfg```" to configure the HAProxy configuration file
  - Refer to this [CONFIG](../High_Availability/Load_Balancers/haproxy.conf) file for ```haproxy.cfg```
  - Set the server name to your local DNS entry for the kubernetes master nodes as well as their corresponding IP addresses
  - Run "```systemctl restart haproxy```"
  - Run "```systemctl enable haproxy```"
- Run "```nano /etc/keepalived/keepalived.conf```" to configure the ```keepalived``` configuration file
  - Refer to this [CONFIG](../High_Availability/Load_Balancers/keepalived.conf) file for ```keepalived.conf```
  - NOTE: For the ```interface``` field, this is the interface ID -> normally ```eth0```
  - NOTE: For the ```unicast_src_ip``` field, that will be the IP address of the ```CURRENT``` machine the config file is being edited on
  - NOTE: For the ```unicast_peer``` field, this is the IP address of any and all other nodes being configured in the load-balancer cluster
  - NOTE: The ```virtual_ipaddress``` field is the IP address that the will be configured as the IP address that communicates with ```ANY AND ALL``` load balancers in this cluster
    - This ```virtual_ipaddress``` value is the very same value that will be used when setting up the kubernetes cluster's endpoint later on
    - You can refer to this virtual IP address by its value when setting up the k8s cluster later on, but it would make sense to add this virtual IP as a host entry under ```/etc/hosts/``` on all nodes as well
  - Run "```systemctl restart keepalived```"
  - Run "```systemctl enable keepalived```"
  - Verify that it all works as intended:
    - Run "```ip a s```" to show the IP addresses assigned to the interfaces
    - Run "```systemctl stop haproxy```" to stop haproxy
      - This should force the other node in the cluster to automatically pick up the virtual IP address thanks to ```keepalived```
    - Run "```ip a s```" again and the virtual IP address should be gone now
    - On the other node(s) in the load balancer, run "```ip a s```" and you should see that the virtual IP address has been assigned to one of them
    - On the original node that the ```haproxy``` service was stopped, restart it with "```systemctl start haproxy```"
<br>

### NOTE: THE BELOW STEPS ARE RUN ON ALL OF THE MASTER NODES AND THE WORKER NODES FOR THE KUBERNETES CLUSTER

## 7) Setting Up ```containerd``` And Networking
- Run "```sudo apt install -y containerd iptables```" (This is in addition to what was run in step 4 above)
- Configure the networking by running:
  -  "```cat > /etc/sysctl.d/99-k8s-cri.conf <<EOF```"
  -  "```net.bridge.bridge-nf-call-iptables=1```"
  -  "```net.bridge.bridge-nf-call-ip6tables=1```"
  -  "```net.ipv4.ip_forward=1```"
  -  "```EOF```"
- Apply the changes by running "```sysctl --system```"

<br>

## 8) Enabling The Modules
- Run "```modprobe overlay```"
- Run "```modprobe br_netfilter```"
- Run "```echo -e overlay\\nbr_netfilter > /etc/modules-load.d/k8s.conf```"
- Run "```update-alternatives --config iptables```"
  - Enter ```1```

<br>

## 9) Swapping to CgroupV2
- Run "```sudo nano /etc/default/grub```"
  - Add  "```systemd.unified_cgroup_hierarchy=1```" To The Line That Contains ```GRUB_CMDLINE_LINUX```
    - I.E. --> "```GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"```"
- Run "```update-grub```"
- Run "```reboot```

<br>

## 10) Installing Kubernetes (This is the portion that uses the community-owned repo now that the others have been deprecated )
- Run "```curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg```"
- Run "```echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list```"
- Run "```sudo apt update```"
- Run "```sudo apt install -y kubelet kubeadm kubectl```"
- Run "```sudo apt-mark hold kubelet kubeadm kubectl```"
- Run "```ln -s /opt/cni/bin /usr/lib/cni```"

<br>

## 11) Configuring Control Plane (Choose One Master Node To Run These On, The Other Master Nodes Will Be Added To The Cluster With The Join Command Later)
- Run "```kubeadm init --control-plane-endpoint=<your_load_balancer_IP_address> --pod-network-cidr=<your_pod_network/16> --upload-certs```"
  - Make note of and save the tokens, hash value, and commands printed/generated for you here as they are used in the next step
- Run "```mkdir -p $HOME/.kube```"
- Run "```cp -i /etc/kubernetes/admin.conf $HOME/.kube/config```"
- Run "```chown $(id -u):$(id -g) $HOME/.kube/config```"
- Run "```wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml```" (This is for the Calico networking plugin)
- Run "```kubectl apply -f calico.yaml```"
- Run "```kubectl get nodes```" -> Stop here until ```STATUS``` says ```Ready```
- Run "```kubectl get pods -A```" -> Stop here until ```STATUS``` says ```Running``` for all pods
<br>

## 12) Joining Other Master Nodes
- We need to make sure the other master nodes have the certificates generated from the master node that was used to initiate the cluster:
  - Copy the certificates over to the other master nodes (Make Sure You Have The Correct Permissions To Allow This, Default Permissions Are 600)
  - Run "```scp user@currentMasterNode:/path/to/kube/certs/*ca.pem user@otherMasterNode:/path/to/keep/certs/*ca.pem```
    - The certs are usually found under ```/etc/kubernetes/pki/```
    - Do this for each ```*ca.pem``` file for each master node in the cluster
  - Run the command that was generated for you in step 11 for the worker nodes
    - It should look something like: "```kubeadm join <virtual_IP_address_of_load_balancer>:6443 --token <your_generated_token> --discovery-token-ca-cert-hash sha256:<your_generated_hash> --control-plane --certificate-key <cert_key_hash>```"
  - Run "```kubectl get nodes```" and wait until ```STATUS``` reads ```Ready``` for all nodes
    - If a master node is stuck, try restarting the ```kubectl``` and ```containerd``` services.
    - If that still doesn't work, disable ```apparmor``` and restart the ```kubectl``` and ```containerd``` services
<br>

## 13) Joining The Worker Nodes
- Run "```kubeadm join <endpoint_used_in_init_cmd>:6443 --token <your_generated_token> --discovery-token-ca-cert-hash sha256:<your_generated_hash>```
- Run "```kubectl get nodes```" and wait until ```STATUS``` reads ```Ready``` for all nodes
  - If a worker node is stuck, try restarting the ```kubectl``` and ```containerd``` services.
  - If that still doesn't work, disable ```apparmor``` and restart the ```kubectl``` and ```containerd``` services
<br>

### And That's It! The Highly Available Multi-Master Kubernetes Cluster Is Now Set Up With A Redundant Load Balancer In Front Of The Cluster!