# Issuing Certificates To Vault And Consul Nodes

<br>

- We are first going to cover setting up the intermediate CA for each (separation of duties)
- For Consul, this will be a normal intermediate CA with a default issuer and role; we will add an ACME role later on
- For Vault, this will also be an intermediate CA with a default issuer and role, but this will include a role for the Vault nodes and a role for the Consul agents on the vault nodes; we will add another role for ACME later on

- For each of these intermediate CAs, it is assumed that you have read the ```Creating PKI Secrets Engines``` section.
- We will create two Intermediate CAs - name one something like ```pki-vault``` and the other something like ```pki-consul```
  -  Reference the ```Setting Up An Intermediate CA``` portion of ```Creating PKI Secrets Engines``` section for this

### For both Intermediate CAs:
- Make sure to populate the ```Issuer URLs``` found under ```Secrets```->```<Engine_Name>```->```Issuers```->```Configure```
  - These should point to the load balancer entry point + the relevant api endpoint
  - For example: ```https://vault.homelab.lan/v1/pki-vault/ca``` for the ```Issuing certificates``` field
  - Make sure to update the SANs field and IP SANs field for these issuers that will cover all allowed certificate requests
    - We use the roles functionality to restrict what can actually be requested

### For the vault intermediate CA:
- Go under ```roles```
- Click on ```Create role +```
- Like with the issuer for the intermediate CA, fill out all relevant fields:
  - Give the role a name under ```Role name```
  - Set the ```TTL``` field (this can be shorter than the intermediate CA's TTL)
  - Add in the allowed domains this role will issue certificates for - this should cover the FQDN of each vault node
    - Tick ```Allow bare domains```
    - Ensure ```Enforce hostnames``` is ticked, optionally chose whether or not to keep ```Allow localhost``` ticked
  - Set Key Parameters at your discretion - I typically opt the 4096 bits option with 512 signature bits option
  - Set Key Usage:
    - Keep the default options ticked (```Digital Signature```, ```Key Agreement```, ```Key Encipherment```)
    - Tick ```Server Auth``` and ```Client Auth```
  - If using policies to lock down access, set the policy under ```Policy Identifiers```
  - Expand the ```Subject Alternative Name (SAN) Options``` menu
    - Ensure that the ```Allow IP SANs``` option is ticked
  - Expand the ```Additional subject fields``` menu
    - Fill these out to your liking
  - Scroll down and click on ```Create```

### For the consul intermediate CA:
- Do exactly the same thing as above for a role named something like ```Consul Clients``` and another role named ```Consul Servers```
- The ```Consul Clients``` role should cover the FQDN of the Vault nodes - this role will be used to issue certificates for consul agents on the vault nodes
- The ```Consul Servers``` role should cover the FQDN of the Consul Server Nodes
- For both of these roles, you must add ```server.dc1.consul``` to the ```Allowed Domains``` as this is the name of the data center value we configured Consul to use in its ```consul.hcl``` file
  - ```dc1``` - if different than ```dc1``` then this follows the ```server.<datacenter_name>.consul``` scheme
- You *MUST* enable ```Allow IP SANs``` as consul uses IP addresses for inter-cluster communication


### For Vault:
- Go to your vault pki engine
- Scroll down to ```Issue certificate```
- Select the role you just created and then click on ```Issue```
- Fill out the:
-  ```Common name``` field
- ```TTL``` field
- Expand ```Subject Alternative Name (SAN) Options``` menu
  - Add the FQDN of the Vault Node to the ```Subject Alternative Names (SANs)``` field - click ```Add```
  - Add the IP address of the individual node to the ```IP Subject ALternative Names (IP SANSs)``` field - click ```Add```
  - Click ```Generate```
  - Copy the private key and certificate and store in a safe place, these will be used later to create the full chain needed
- Repeat for each node

### For Consul:
- Consul Servers:
  - Go to your consul pki engine
  - Scroll down to ```Issue certificate```
  - Select the role you just created for the consul servers and then click on ```Issue```
  - Fill out the:
  -  ```Common name``` field
  - ```TTL``` field
  - Expand ```Subject Alternative Name (SAN) Options``` menu
    - Add the FQDN of the Consul Server Node to the ```Subject Alternative Names (SANs)``` field - click ```Add```
    - Add the server datacenter name (```server.dc1.consul```) to the ```Subject Alternative Names (SANs)``` field - click ```Add```
    - Add the IP address of the individual node to the ```IP Subject ALternative Names (IP SANSs)``` field - click ```Add```
    - Click ```Generate```
  - Copy the private key and certificate and store in a safe place, these will be used later to create the full chain needed
  - Repeat for each node
- Consul Agents:
  - Now Select the role you just created for the consul clients and then click on ```Issue```
  - Fill out the:
  -  ```Common name``` field
  - ```TTL``` field
  - Expand Subject Alternative Name (SAN) Options``` menu
    - Add the FQDN of the *VAULT* node to the ```Subject Alternative Names (SANs)``` field - click ```Add```
    - Add the server datacenter name (```server.dc1.consul```) to the ```Subject Alternative Names (SANs)``` field - click ```Add```
    - Add the IP address of the individual node to the ```IP Subject ALternative Names (IP SANSs)``` field - click ```Add```
    - Click ```Generate```
  - Copy the private key and certificate and store in a safe place, these will be used later to create the full chain needed
  - Repeat for each consul agent on each vault node

### Creating A Load Balancer Entrypoint Intermediate CA
- First, we need to create a certificate for the entry point on our load balancer so that when we send the request to our entry point, it's encrypted and then subsequently terminated at the load balancer before being re-encrypted and sent to our backend clusters.
- In a similar manner to how we set up the consul and vault intermediate CAs, we're going to set up another intermediate CA for all of our load balancer related certificates.
- Following the same procedure we used in the ```Setting Up An Intermediate CA``` section of ```Creating PKI Secrets Engines```, create a ```pki-loadbalancer``` engine
- Once set up, configure the engine for the ```AIA``` path, ```Cluster path```, and the Global URLs for ```Isssuing```, ```CRL```, and ```OCSP```.
- Populate all SAN related fields for ```Allowed Domains``` and the ```Additional SANs Options``` fields
- Tune this engine to your preference for things like key usage and TTL, ensure that ```Server Auth``` and ```Client Auth``` are enabled in key usage
- Create separate roles for each load balancer endpoint, or optionally, create a role to issue wildcard certificates
- Create a certificate for your load balancer node(s) and VIP (if using multiple load balancers) and save the cert and key somewhere safe
  - On the load balancer pki engine, create a certificate that covers the load balancer host and IP address
    - Save the resulting certificates and private key somewhere safe
  -  Create a combined certificate chain that will be used to present to the server backends:
     - The private key
     - The leaf cert
     - The load balancer CA cert
     - The root cert
- Create a ca chain file that just contains the ca chain for the load balancer - this will be used as our ```tls_client_ca_file``` in the ```vault.hcl``` config:
  - Load balancer cert
  - Root CA cert
- Next, generate certificates for your vault and consul entrypoints and save the certificates and keys somewhere safe.
- Create a full chain certificate that includes the private key (this is necessary for terminating the connection at the load balancer and re-encrypting the connection)
- Like for the load balancer full ca chain cert, we need to provide the frontend a full ca chain certificate to terminate the SSL connections
  - For each entrypoint, create a full ca chain with:
    - The private key
    - The leaf cert
    - The appropriate Intermediate CA cert (```pki-vault``` for vault's and ```pki-consul``` for consul's)
    - The Root CA cert
- Next, we need the Intermediate CA certificate and Root CA certificate to form a CA chain for the backends
  - Create this combined chain file for vault and another for consul
- Finally, for consul to trust our load balancer, we need to present our load balancer certificate chain on consul's backend (this is in preparation for mTLS)
- We now have all the certificates that we need to make this next step work

<br>

# Distributing Certificates To The Nodes And Updating The Configs For Vault and Consul
- For each vault node cert:
  - Create a combined certificate file that contains the following in order:
    - the leaf certificate
    - the intermediate CA certificate (```pki-vault```'s certificate)
    - the root CA certificate (```pki-root```'s or your external root CA that signed the CSR for ```pki-vault```'s certificate)
  - Repeat this process for each vault node - if you have 3 nodes, you should have 3 individual combined certificate files
  - This provides the full CA chain file for the ```tls_client_ca_file``` variable that we will be adding to the ```vault.hcl``` file
- For each consul node cert:
  - Create a combined certificate file that contains the following in order:
    - the leaf certificate
    - the intermediate CA certificate (```pki-consul```'s certificate)
    - the root CA certificate (```pki-root```'s or your external root CA that signed the CSR for ```pki-consul```'s certificate)
  - Repeat this process for each consul server node - if you have 3 nodes, you should have 3 individual combined certificate files
  - This provides the full CA chain file for the ```ca_file``` variable that we will be adding to the ```consul.hcl``` file
- We are going to repeat this process for the Vault Consul Agent Certificates:
  - Create a combined certificate file that contains the following in order:
    - the vault's consul agent leaf certificate
    - the intermediate CA certificate (```pki-consul```'s certificate)
    - the root CA certificate (```pki-root```'s or your external root CA that signed the CSR for ```pki-consul```'s certificate)
  - Repeat this process for each vault consul agent - if you have 3 nodes, you should have 3 individual combined certificate files
    - This provides the full CA chain file for the ```tls_ca_file``` variable that we will be adding to the ```vault.hcl``` file on the vault nodes
  - For the load balancer certificates:
    - Copy the full chain certificates for the load balancer, consul, and vault to the ```/etc/haproxy/certs``` directory
    - Copy the CA chain certificates for vault, consul, and the load balancer to the ```/etc/haproxy/ca``` directory

<br>

- SSH into each vault node:
  - Copy the Vault specific leaf certificate and the key to ```/etc/vault.d/tls``` for each respective node, including the load balancer CA chain certificate
  - Next, copy the Consul Agent leaf certificate, full chain certificate, and the key to ```/etc/consul.d/tls``` for each respective node
  - Edit the ```/etc/vault.d/vault.hcl``` file on the vault node and add the following:
    - Under ```listerner "tcp"```
      - Ensure ```tls_disable = "false"```
      - Add ```tls_cert_file = "/etc/vault.d/tls/<vault_node_cert>"```
      - Add ```tls_key_file = "etc/vault.d/tls/<vault_node_key>"```
      - Add ```tls_client_ca_file = "/etc/vault.d/tls/<load-balancer-pki-ca-chain-cert>"```
    - Under ```storage "consul"```
      - Add ```tls_ca_file    = "/etc/consul.d/tls/<vault_consul_agent_fullchain_cert>"```
      - Add ```tls_cert_file  = "/etc/consul.d/tls/<vault_consul_agent_cert>"```
      - Add ```tls_key_file   = "/etc/consul.d/tls/<vault_consul_agent_key>"```
  - Edit the ```/etc/consul.d/consul.hcl``` file on the vault node and add the following:
    - Add ```ca_file = "/etc/consul.d/tls/<vault_consul_agent_fullchain_cert>"```
    - Add ```cert_file = "/etc/consul.d/tls/<vault_consul_agent_cert>"```
    - Add ```key_file  = "/etc/consul.d/tls/<vault_consul_agent_key>"```
  - *DO NOT* restart the services yet
- SSH into each consul node:
  - Copy the Consul Server leaf certificate, full chain certificate, and the key to ```/etc/consul.d/tls``` for each respective node
  - Edit the ```/etc/consul.d/consul.hcl``` file on the vault node and add the following:
    - Add ```ca_file = "/etc/consul.d/tls/<consul_server_fullchain_cert>"```
    - Add ```cert_file = "/etc/consul.d/tls/<consul_server_node_cert>"```
    - Add ```key_file  = "/etc/consul.d/tls/<consul_server_node_key>"```
- On the Consul Server Nodes:
  - Restart each consul service and ensure that the nodes rejoin the consul cluster
- On the Vault Nodes:
  - Restart each consul service and ensure that the agents rejoin the consul cluster
  - Restart each vault service
- Each Vault and Consul Node now utilize certificates issued to each individual node
- Vault has now been configured to start communicating with its consul agent and have the consul agent reach out to the consul cluster in a secure manner as well


# Looking Forward
- Next, we'll cover
  - Migrating the consul and vault nodes to use the https scheme
  - Updating our load balancer frontend to use its own certificate so that we can:
    - Serve https traffic to the frontend
    - Terminate the SSL connection at the load balancer
    - Re-encrypt traffic that is sent to the backend clusters
  - Updating Consul Agents and Consul Servers to utilize mTLS and updating the load balancer config to handle this
  - Finally, we will then cover setting up an ACME endpoint for these two intermediate CAs and installing/configuring certbot on each of our nodes for automatic certificate renewal (some deploy hook scripting will be required)