# Making Both Vault and Consul A Highly Available Cluster
- The perquisites for this is at least having one vault node and one consul node up and running.
- Load Balancer Endpoint to distribute traffic at a common entry point to the cluster backends (I'm using HAProxy for this)
- We're going to start with making the storage backend (consul) highly available as vault is straight forward (just throw more nodes at it)

# Converting Our Single Consul Node To A Highly Available Consul Cluster
- Fire up as many nodes as you wish to have in your cluster, keeping in mind that odd numbers are required for leader election
- Follow the ```Setting Up A Standalone Consul``` section on each node you plan on adding to this cluster
  - NOTE: *DO NOT* run the consul services yet since we need to make some alterations to the config files
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
  - NOTE:
    - Since we initially had the single Vault node registered without a ```node_name``` name value, it uses a default value of ```vault``` for this field for consul registration.
    - When we create a highly available vault cluster we start using node names for the consul agents on these vault nodes and register them with the consul cluster via the consul agent.
    - Because of this, an orphaned health check service will be present when checking the vault node's health from consul due to it being initially registered by vault itself and not the local agent.
  - To rectify this, all we need to do is deregister the single vault node from health checks on consul
    - Run ```curl -s http://127.0.0.1:8500/v1/agent/services```
    - If you see something like ```"vault:<vault_node_ip>:8200"```, it will become stale when the vault cluster is created.
    - Deregister this health check with ```consul services deregister -id="vault:<vault_node_ip>:8200"```
    - Confirm its removal with ```curl -X PUT http://127.0.0.1:8500/v1/agent/service/deregister/vault:192.168.20.9:8200```

# Converting Our Single Vault Node To A Highly Available Vault Cluster
- Fire up as many nodes as you wish to have in your cluster, keeping in mind that odd numbers are required for leader election
- Follow the ```Setting Up A Standalone Vault``` section on each node you plan on adding to this cluster
  - NOTE: *DO NOT* run the vault services just yet though or else we run into stale health service checks mentioned above since the cluster hasn't been created yet.
- On each node, modify the ```vault.hcl``` file:
  - Add ```api_addr="http://<FQDN>:8200"```
  - Add ```cluster_addr="http://<IP ADDRESS OF NODE>:8200"```
  - Modify the ```storage``` field's ```address``` value to the specific Vault Node's IP Address.
    - NOTE: After this step, we will be installing a local consul agent that the vault service will communicate to the cluster through.
    - The local agent acts as a proxy endpoint for vault so that if any consul servers go down, it will try to reconnect to another known consul server.
  - Our current ```vault.hcl``` should look something like:
```
ui = true
api_addr = "https://vault-01.homelab.lan:8200"
cluster_addr = "https://192.168.20.6:8200"

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "false"
  tls_cert_file = "/etc/vault.d/vault-01_cert.pem"
  tls_key_file  = "/etc/vault.d/vault-01_key.pem"
}

storage "consul" {
  address = "192.168.20.6:8500"
  path    = "vault/"
}
```
# Installing A Local Consul Agent
- By Installing a local consul agent on each vault node, the vault service only needs to communicate locally with its agent
- The agent in return will be configured to reach out to the cluster to join; it will not act as a server
- Overall, the process for this is the same as installing and deploying an actual consul node
- Follow the steps found in the ```Setting Up A Standalone Consul``` section and stop at the portion that states to run the service. When you have reached that portion, return here to proceed
- Now that we have consul installed and the service configured, there are some changes that we need to make to allow this instance to act as a local agent
- Modify the ```consul.hcl``` file on the vault node, effectively the changes we're making here reflect the changes we made on the consul servers:
  - Add ```node_name=""```, example: ```node_name="vault-01_agent"```
  - Add ```advertise_addr="X.X.X.X"``` - set this to the individual node's *IP* address, this must be the *IP* address to permit inter-cluster communication between the nodes
  - Set ```server=false```, this line change makes it act as an agent
  -  Add ```retry_join =[]``` and populate it with the cluster server list
  -  Make sure that the ```bootstrap_expect``` variable and value has been removed from this instance; this isn't needed for an agent
- All together, the ```consul.hcl``` config for the vault's consul agent should look something like:
```
node_name      = "vault-01_agent"
bind_addr      = "0.0.0.0"
advertise_addr = "192.168.20.6"
client_addr    = "0.0.0.0"
data_dir       = "/var/lib/consul"
log_level      = "INFO"
server         = false
ui            = true
retry_join = [
  "consul-01.homelab.lan",
  "consul-02.homelab.lan",
  "consul-03.homelab.lan"
]
```

# Wrapping Up The Vault Cluster
- All that's left to do is start up the consul agents, ensure they reach the cluster, and then spin the vault cluster nodes up
- Start the Consul Service:
  - ```sudo systemctl start consul``
- Check the status of the vault agent:
  - ```sudo systemctl status consul```
  - ```sudo journalctl -xeu consul```
- Start the Vault Service
  - ```sudo systemctl start vault``
- Check the status of the Vault node
  - ```sudo systemctl status vault```
  - ```sudo journalctl -xeu vault```
- Once you verify that the agents are reaching out to the Consul cluster nodes and that the vault nodes have either been set as active or standby, you're all set to go.
- The last thing left is to unseal the vault cluster again. To do this, we need to unseal each vault node using the same unseal keys we were given when the first node was created and initialized
- On each Vault node:
  - Run: ```export VAULT_ADDR=http://<node_IP_Address>``
  - If a certificate is used for TLS, then you will also need to run: ```export VAULT_CACERT=/path/to/cert/<name_of_cert>.<cert_extension>```
  - Run: ```vault operator unseal <key1>``` - repeat this with 2 more keys
  - Now all nodes will have been unsealed - this can be verified by running ```vault status``` on each node
  - Next, to find the active node, run: ```vault operator members```
    - This will output info of the active node
    - We can use this info to now migrate over to the active node to login to or navigate over to the UI if it has been enabled

# Integrating A Load Balancer Frontend To Proxy Cluster Requests
- It would be a royal pain to always have to log in to a node and figure out if it's the active vault node in the cluster as well as figuring out if a consul node is reachable
- Instead, we can configure a common entrypoint, or frontend, to make our requests to that will run a http health check on the backend servers to automatically dictate which server we need to connect to
- Log into the load balancer running HAProxy and edit the ```haproxy.cfg``` file, commonly located in ```/etc/haproxy/haproxy.cfg```
- We will now create a frontend for http traffic (we will end up moving to https in the future) and use acl's to do some SNI inspection for the URL request:
``` cfg
frontend http-in
    bind *:80
    mode http
    option httplog
    # Frontends
    acl vault_frontend hdr(host) -i vault.homelab.lan
    acl consul_frontend hdr(host) -i consul.homelab.lan
    # Backends
    use_backend vault_backend if vault_frontend
    use_backend consul_backend if consul_frontend
    default_backend no_route

backend vault_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/sys/health
    server vault-01 192.168.20.6:8200 check
    server vault-02 192.168.20.7:8200 check
    server vault-03 192.168.20.8:8200 check

backend consul_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/status/leader
    server consul-01 192.168.20.9:8500 check
    server consul-02 192.168.20.10:8500 check
    server consul-03 192.168.20.11:8500 check

backend no_route
    mode http
    errorfile 503 /etc/haproxy/errors/503.http
```

- Once done, save and reload haproxy: ```sudo systemctl restart haproxy```
- Make sure you have DNS entries for the load balancer frontend URLs used that alias the load balancer
  - I use pfSense, so all that's needed is to go into the DNS Resolver tab and add the alias there
- Now, you should be able to navigate to either ```vault.<FQDN>``` or ```consul.<FQDN>``` and through the power of load balancing, the request will hit the appropriate backend server
- If you run into an error with resolving the vault URL to the backends and have the TLS entries enabled, you will need to present those certs on the backend:
  - Create a combined certificate file with the private key and then the individual node leaf certificate listed
  - Copy over each vault node's combined certificate to ```/etc/haproxy/certs``` and name them something logical, like vault-01.pem
  - Change ownership of these certs on haproxy to haproxy: ```sudo chown -R haproxy:haproxy /etc/haproxy/certs/```
  - Change permissions of these certs to be -rw-|---|---: ```sudo chmod 600 /etc/haproxy/certs/<node_cert>``` - repeat this for each node cert copied over
  - Modify the ```haproxy.cfg``` file to present these certs
``` cfg
backend vault_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/sys/health
    server vault-01 192.168.20.6:8200 check ssl crt /etc/haproxy/certs/<vault_node_cert>.pem
    server vault-02 192.168.20.7:8200 check ssl crt /etc/haproxy/certs/<vault_node_cert>.pem
    server vault-03 192.168.20.8:8200 check ssl crt /etc/haproxy/certs/<vault_node_cert>.pem
```
  - Restart Haproxy, you should now be able to resolve the alias to the backend node