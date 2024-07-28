
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

## 5) Setup Local DNS Entries

#### A) If using a local DNS resolver external to the cluster
  - Add DNS records for the hostname/IP address for each cluster node and load balancers on the resolver
  - Make sure each node can reach that DNS resolver by pinging it from each node
  - Use a tool similar to nslookup or use nslookup itself to check for DNS record resolution from and to nodes

#### B) If you're not using an external DNS resolver of some kind and are relying on internal resolution instead:
  - Run "```nano /etc/hosts/```" on each cluster node and load balancers
  - In each cluster node and load balancer's ```hosts``` file add every other node's local DNS entry and their IP address
  - Next, since this lab's setup uses ```cloud-init```, we need to modify another file to keep the cloud config from overwriting these additions
  - Run "```nano /etc/cloud/cloud.cfg```"
    - Comment out "```update_etc_hosts```"
    - Add "```manage_etc_hosts: false```"
    - Save and exit the file and then reboot.
  - Ensure the newly added host entries weren't overridden by running "```cat /etc/hosts/```"

### NOTE: Step 6 Applies To All Nodes Being Configured In The Load Balancer Cluster Setup

## 6) Configuring The Load Balancer Nodes (For this setup, there are two VMs acting as the load balancer nodes)
- Install both ```keepalived``` and ```haproxy``` by running "```apt install keepalived haproxy psmisc -y```"
- Run "```nano /etc/haproxy/haproxy.cfg```" to configure the HAProxy configuration file
  - Refer to this [CONFIG](../../kubernetes/load-balancers/external/haproxy.conf) file for a simple working ```haproxy.cfg```
  - Set the server name to your local DNS entry for the kubernetes master nodes as well as their corresponding IP addresses
  - Set the frontend port to the bind port you will use for the cluster's api server (default 6443) and direct traffic to the control nodes at port 6443.
    - For example, I use port 7443 so my frontend and backend would like:
    ```
    frontend rmccu-k8s-cluster
        bind *:7443
        mode tcp
        option tcplog
        default_backend rmccu-k8s-cluster-control-plane

    backend rmccu-k8s-cluster-control-plane
        mode tcp
        balance roundrobin
        option tcp-check
        server k8s-controller-01.homelab.lan 192.168.20.7:6443 check fall 3 rise 2
        server k8s-controller-02.homelab.lan 192.168.20.8:6443 check fall 3 rise 2
        server k8s-controller-03.homelab.lan 192.168.20.9:6443 check fall 3 rise 2
    ```
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
- Apply the changes by running "```sudo sysctl --system```"
- Double check that the changes took effect:
- Run ```sudo nano /etc/modules-load.d/k8s.conf``` and add the following if they don't already exist:
  - ```overlay```
  - ```br_netfilter```
  -  Run ```sudo nano /etc/sysctl.conf``` and make sure ```net.ipv4.ip_forward=1``` exists and uncomment it if it's commented out
  -  If anything had to be modified within the self-checks, reboot the server or re-run ```sudo sysctl --system```
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
- NOTE: The ```<version>``` fields in the below lines must match, however, this is the version of kubernetes you would like to install
  - Run "```curl -fsSL https://pkgs.k8s.io/core:/stable:/v<version>/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg```"
  - Run "```echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v<version>/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list```"
- Run "```sudo apt update```"
- Run "```sudo apt install -y kubelet kubeadm kubectl```"
- Run "```sudo apt-mark hold kubelet kubeadm kubectl```"
- Run "```ln -s /opt/cni/bin /usr/lib/cni```"

<br>

## 11) Configuring Control Plane (Choose One Master Node To Run These On, The Other Master Nodes Will Be Added To The Cluster With The Join Command Later)
- Run ```sudo kubeadm config images pull --kubernetes-version=v<version>``` to pre-fetch images that the cluster needs.
  - You can leave the ```--kubernetes-version``` field blank if you want to use the kubernetes version that coincides with kubeadm's version
- Run "```kubeadm init --control-plane-endpoint=<your_load_balancer_IP_address> --pod-network-cidr=<your_pod_network/16> --upload-certs```"
  - You can also do this step with a config file, for example, you can create a ```kubeadm-config.yaml``` file
  -  For Example, my config looks like the following:
      ```
      apiVersion: kubeadm.k8s.io/v1beta3
      kind: ClusterConfiguration
      kubernetesVersion: 1.30.3
      clusterName: rmccu-k8s-cluster
      controlPlaneEndpoint: "load-balancer.homelab.lan:7443"
      networking:
        podSubnet: "172.18.0.0/16"
        serviceSubnet: "10.244.0.0/16"
      apiServer:
        certSANs:
          - load-balancer.homelab.lan
          - 192.168.20.5
        timeoutForControlPlane: "5m0s"
      ```
      And then run ```sudo kubeadm init --config=kubeadm-config.yaml --upload-certs```
- There is sometimes a version mismatch with what kubeadm pulls and what is sometimes used (looking at you containerd and Pause...)
  - In this case, locate the manifests directory, typically found under ```/etc/kubernetes/manifests```
  - Update the image tag to reflect what should have been pulled and save the changes for the appropriate file
  - Since these components are managed as static pods, kubelet will automatically update the pods from here
  - To verify that the correct versions are being used now
    - Run ```sudo ctr images list``` to check the image versions
    - Run ```kubectl get pods -n kube-system``` to check the pods have updated to the new images
  - However, if there's a mismatch with the containerd's version of Pause and kubeadm's version (which is most likely as containerd uses 3.6 as the time of this writing)
    - Run ```sudo ctr image pull registry.k8s.io/pause:<version>``` to pull the correct version of ```Pause``` into ```containerd```, changing <version> to match what was listed with ```kubeadm config images pull``` or ```kubeadm config images list```
    - Run ```sudo nano /etc/containerd/config.toml```
      - Locate ```[plugins."io.containerd.grpc.v1.cri"]```
      - Change the ```<version>``` in ```sandbox_image = "registry.k8s.io/pause:<version>"``` to match your image version
    - Run ```sudo systemctl restart containerd```
- Make note of and save the tokens, hash value, and commands printed/generated for you here as they are used in the next step
- Run "```mkdir -p $HOME/.kube```"
- Run "```cp -i /etc/kubernetes/admin.conf $HOME/.kube/config```"
- Run "```chown $(id -u):$(id -g) $HOME/.kube/config```"
- Run "```kubectl get nodes```" -> You should see your node pop up with A ```Not Ready``` - this is fine as the CoreDNS pods need a CNI installed before the node is marked ```Ready```
<br>

## 12) Joining Other Master Nodes
  - Run the command that was generated for you in step 11 for the worker nodes
    - It should look something like: "```kubeadm join <virtual_IP_address_of_load_balancer>:<bindPort> --token <your_generated_token> --discovery-token-ca-cert-hash sha256:<your_generated_hash> --control-plane --certificate-key <cert_key_hash>```"
  - Repeat the process for the kubeconfig by running
     - "```mkdir -p $HOME/.kube```"
     - "```cp -i /etc/kubernetes/admin.conf $HOME/.kube/config```"
     - "```chown $(id -u):$(id -g) $HOME/.kube/config```"
  - After the last node has been added, run "```kubectl get nodes```", you should now see all master nodes listed
    - If a master node is stuck and isn't joining the cluster after some time or errors out
      - Run ```sudo systemctl status kubectl``` or ```sudo systemctl status containerd``` to check that these are enabled and running
      - Run ```sudo journalctl -xeu kubectl``` or ```sudo journalctl -xeu containerd``` to view the logs and see if there are any errors present
      - Run ```sudo rm -rf /etc/kubernetes``` and ```sudo rm -rf /etc/cni/net.d``` to effectively start fresh
      - Try restarting the ```kubectl``` and ```containerd``` services on that node
      - Retry joining the node to the cluster
    - If that still doesn't work:
      - Run ```sudo rm -rf /etc/kubernetes``` and ```sudo rm -rf /etc/cni/net.d``` to effectively start fresh again
      - Try disabling ```apparmor``` and restart the ```kubectl``` and ```containerd``` services on that node
      - Check the logs and status of the modules again
      - Retry joining the node to the cluster
<br>

## 13) Joining The Worker Nodes
- Run "```kubeadm join <endpoint_used_in_init_cmd>:<bindPort> --token <your_generated_token> --discovery-token-ca-cert-hash sha256:<your_generated_hash>```
- Run "```kubectl get nodes```" and wait until ```STATUS``` reads ```Ready``` for all nodes
  - If a worker node is stuck, try restarting the ```kubectl``` and ```containerd``` services.
  - If that still doesn't work, disable ```apparmor``` and restart the ```kubectl``` and ```containerd``` services
<br>

### And That's It! The Highly Available Multi-Master Kubernetes Cluster Is Now Set Up With A Redundant Load Balancer In Front Of The Cluster! Next Step Is To Install A CNI Of Your Choice. I Use Calico CNI In BGP Mode Peered With My Router And MetalLB As My Service IP Provisioner. Both Of These Setups Are Explained Under ```calico/installation.md``` And ```metallb/installation.md``` Files Respectively.
