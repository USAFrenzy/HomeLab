# Making Both Vault and Consul A Highly Available Cluster
- The perquisites for this is at least having one vault node and one consul node up and running.
- We're going to start with making the storage backend (consul) highly available as vault is straight forward (just throw more nodes at it)

# Converting Our Single Consul Node To A Highly Available Consul Cluster
- Fire up as many nodes as you wish to have in your cluster, keeping in mind that odd numbers are required for leader election
- Follow the ```Setting Up A Standalone Consul``` section on each node you plan on adding to this cluster
- For each consul node, make changes to the ```consul.hcl``` config file by adding the below fields:
  - Add ```node_name=""``` - set this to a descriptive and unique name, I opted to use the hostname
  - Add ```advertise_addr="X.X.X.X"``` - set this to the individual node's *IP* address, this must be the *IP* address to permit inter-cluster communication between the nodes
  - Change ```bootstrap_expect=1``` to however many nodes you are adding to this cluster
  -  Add ```retry_join =[]``` - this is an array of nodes to add to the cluster, FQDN should be preferred here. For example, in a 3 node environment, it may look like:
```
retry_join = [
  "consul-01.homelab.lan",
  "consul-02.homelab.lan",
  "consul-03.homelab.lan"
]
```
  - On each node, restart the consul service: ```sudo systemctl restart consul```
  - Check the status and logs to ensure cluster creation and communication
    - ```sudo systemctl status consul``` and ```sudo journalctl -xeu consul```
  - Run ```consul members``` to validate that all nodes added to the cluster are ```alive```
- Since we initially had the single Vault node registered without a ```node_name``` name value, it uses a default value of ```vault``` for this field. When we create a highly available vault cluster we start using node names for the vault nodes and consul agents, so an orphaned health check service will be present when checking the vault node's health from consul since the cluster will instead use the local agent on vault for health checks.
  - To rectify this, all we need to do is deregister the single vault node from health checks on consul
    - Run ```curl -s http://127.0.0.1:8500/v1/agent/services```
    - If you see something like ```"vault:<vault_node_ip>:8200"```, it will become stale when the vault cluster is created.
    - Deregister this health check with ```consul services deregister -id="vault:<vault_node_ip>:8200"```
    - Confirm its removal with ```curl -X PUT http://127.0.0.1:8500/v1/agent/service/deregister/vault:192.168.20.9:8200```

# Converting Our Single Vault Node To A Highly Available Vault Cluster
- Fire up as many nodes as you wish to have in your cluster, keeping in mind that odd numbers are required for leader election
- Follow the ```Setting Up A Standalone Vault``` section on each node you plan on adding to this cluster
  - NOTE: *DO NOT* run the vault services just yet though or else we run into stale health service checks mentioned above since the cluster hasn't been created yet.