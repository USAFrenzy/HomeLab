## Installing and Deploying Calico CNI and Calicoctl
- Run ```kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml``` replacing <version> with the appropriate version you would like to use
- Run ```curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O```
  - Make changes to this config file to reflect the service and pod subnet used when initializing the cluster
- Run ```kubectl apply -f custom-resources.yaml```
- Run ```watch -n2 kubectl get tigerastatus``` to view the status of the ```apiserver```, ```calico```, and ```ippools```
  - This may take some time to set up and you may receive the following errors:
    - ```Unable to connect to the server: EOF```
    - ```Error from server: etcdserver: request timed out```
    - ```Error from server (Forbidden): tigerastatuses.operator.tigera.io is forbidden: User <user> cannot list resource "tigerastatuses" in API group "operator.tigera.io" at the cluster scope```
    - Give it some time to situate itself and it should resolve itself in a few minutes
  - When all 3 are marked as ```Available```, then calico has successfully been installed and deployed as the CNI
- I decided to run calicoctl as a binary on each host node, so on each of my control nodes, I ran:
  - ```sudo curl -L https://github.com/projectcalico/calico/releases/download/v3.28.0/calicoctl-linux-amd64 -o calicoctl```
  - ```sudo chmod +x ./calicoctl```
  - ```sudo mv ./calicoctl /usr/local/bin/calicoctl```

<br>

## Establishing BGP:
- The basic requirements for establishing BGP with calico are:
  - Ideally no encapsulation or overlays, however absolutely no ```VXLAN``` overlays
    - NOTE: ```IPIP``` works just fine though (this is my setup due to the VM hosts being in one VLAN while the hypervisor is in a separate VLAN)
  - Either a physical or virtual router that supports BGP for peering
  - ```calicoctl``` is installed and configured
  - The next choice is a discretionary decision. There are 3 modes to choose from: Full-mesh (the default), route reflectors, and top of rack
    - Full Mesh: peers every node in the cluster to one another
    - Route Reflectors: reduce the total bgp peers from the default setup by using a hierarchy of nodes. You designate which ones will act as reflectors and then those reflectors pair with other reflectors. The nodes that aren't configured as reflectors peer with the reflector nodes instead, reducing the total amount of peer pairs that need to be established.
    - Top of Rack: peers directly with physical architecture to establish BGP connections (this is my choice as I run pfSense with FRR installed using BGP and OSPF)

<br>

- No matter which mode you pick, you will need a base config to deploy for BGP; the following is how my config looks:
  ```
    apiVersion: projectcalico.org/v3
    kind: BGPConfiguration
    metadata:
      name: default
    spec:
      logSeverityScreen: Info
      asNumber: 65201 # Set to the AS number you want to use for BGP. All of the calico nodes will use this ASN when establishing a peer
      serviceClusterIPs:
        - cidr: 10.244.0.0/16 # This should match the serviceSubnet in the ClusterConfiguration
      serviceLoadBalancerIPs:
        - cidr: 10.243.160.0/27 # This is the range of IP addresses that matches the IP range available to MetalLB k8s-pool
        - cidr: 192.168.20.5/32 # This is the VIP address that matches the IP available to MetalLB loadbalancer-vip pool
    ```
    - Notice that I have included load balancer IP ranges; this is due to also using metallb in my cluster to assign service IP addresses from a different subnet

  <br>

### Full Mesh Method
-  The Full Mesh method requires no additional configuration as this is the default method and every node will establish a peer pair with one another

### Route Reflector Method
-  The Route Reflectors method requires minimal configuration to setup:
- You would assign any nodes that will act as a reflector with a Cluster ID by running:
  - ```kubectl annotate node <node_name> projectcalico.org/RouteReflectorClusterID=<unused_IPv4_address>```
- You would then label each node with some meaningful label so that it can be easily referred to in the BGPPeer configs.
  - Ex: ```kubectl label node <node_name> route-reflector=true```
- Then, just like with any other BGPPeer config, you would setup a peer, adding the ```peerSelector``` with whatever label you created for the node:
  ```
  kind: BGPPeer
  apiVersion: projectcalico.org/v3
  metadata:
    name: peer-with-route-reflectors
  spec:
    nodeSelector: all()
    peerSelector: route-reflector == 'true'
  ```
<br>

### Top Of Rack Method
- Given that I am using a pseudo-Top of Rack method, I use a global bgp peer for my router to the nodes - this peers every node in the cluster to my router and looks like:
  ```
   apiVersion: projectcalico.org/v3
   kind: BGPPeer
   metadata:
     name: router
   spec:
     peerIP: 10.10.10.1
     asNumber: 65200
     filters:
     -  import-external-routes
     -  export-external-service-network
     -  deny-internal-service-network
     -  deny-pod-network
  ```
  - Important notes:
    - For the Top of Rack method, you would typically add ```nodeSelector: rack == 'rack-designator'``` to the spec field and then label the nodes you want to use this bgp peer config with ```rack:rack-designator```. In my setup, I simply wished for the BGP routes to be advertised to my router, which uses both BGP and OSPF to establish the most efficient route paths with future expansion in mind, so I stuck with a simple global peer for now which effectively creates a full-mesh with my router instead
    - peerIP is the IP address that this cluster can reach the router at, my router uses a host of VLANs and subnets, so I chose the VM_Network gateway address due to the cluster nodes residing in that VLAN network
    - asNumber is the ASN of your router
    - filters is any filter you would like to apply to this peer

  ### Adding filters
  - Filters act as a method to control what routes are imported/exported
  - You can be as granular as you want to with these filters, only allowing or rejecting subsets of a network, or as broad as you want to and allow the whole subnet
  - In my setup, I simply created a few filters. As examples:
    - One to reject advertisement of the internal pod network and applied it to my peer config above so that my router doesn't see my pod network and only sees the service network and the cluster's network from calico. My config for that looks like:
    ```
     apiVersion: projectcalico.org/v3
     kind: BGPFilter
     metadata:
       name: deny-pod-network
     spec:
       exportV4:
       - action: Reject
         matchOperator: In
         cidr: 172.18.0.0/16 # This should match the podSubnet in the ClusterConfiguration

    ```
    - And another to allow advertisement of the services from the IP addresses that MetalLB assigns to my router peer above:
    ```
    apiVersion: projectcalico.org/v3
    kind: BGPFilter
    metadata:
      name: allow-service-network
    spec:
      exportV4:
      - action: Accept
        matchOperator: In
        cidr: 10.243.160.0/27 # This is the range of IP addresses that matches the IP range available to MetalLB k8s-pool
    ```

<h3 style="text-align: center"> Final Step </h3>
<h5 style="text-align: center;"> NOTE: <br> <p style="text-align: center;">In my network, I have an external load-balanced load balancer running haproxy and keepalived which receives all incoming traffic and routes it to my other machines as well as the kubernetes cluster. Because the routes essentially skip this load balancer, I have to make one minor adjustment for this to work correctly. I need to add the routes to get to the metallb network on these load balancers. To do this, we are going to install the "FRR" package on the load balancers and configure them as bgp peers to both the cluster and to the top-level router (pfSense in my case) </p></h5>

- Run ```sudo apt install frr frr-pythontools```
- Enable BGP in the ```daemons``` file
  - ```sudo nano /etc/frr/daemons``` and change ```bgpd``` to ```yes```. Save and exit
- Edit the ```bgpd.conf``` file by running ```sudo nano /etc/frr/bgpd.conf```
  - Add the bgp configuration information for the router (or other peers) and calico here, save and exit.
  - For example, mine looks like this where the configs are identical on each machine with the ```router-id``` field being changed appropriately:
   ```
   router bgp 65202
    bgp router-id 192.168.20.3 # IP of the VM
    neighbor 10.10.10.1 remote-as 65200
    neighbor 192.168.20.7 remote-as 65201
    neighbor 192.168.20.8 remote-as 65201
    neighbor 192.168.20.9 remote-as 65201

    address-family ipv4 unicast
     network 192.168.20.0/26
     neighbor 10.10.10.1 activate
     neighbor 192.168.20.7 activate
     neighbor 192.168.20.8 activate
     neighbor 192.168.20.9 activate
     maximum-paths 3 # Change this to however many paths you'd like to use for the same destination
    exit-address-family
   ```
- Restart the ```frr``` service by running ```sudo restart frr```
- Go to the top level router (could be VyOS, or any other router that supports BGP - mine is pfSense)
  - Establish a neighbor with whatever ASN and IP was given to the load balancers - in my example, it was 65202 and the VIP of 192.168.20.5
- To verify the sessions are established:
  - Run ```ip route``` to view the routes on the load balancer nodes