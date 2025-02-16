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

- SSH into each vault node:
  - Copy the Vault specific leaf certificate, full chain certificate, and the key to ```/etc/vault.d/tls``` for each respective node
  - Next, copy the Consul Agent leaf certificate, full chain certificate, and the key to ```/etc/consul.d/tls``` for each respective node
  - Edit the ```/etc/vault.d/vault.hcl``` file on the vault node and add the following:
    - Under ```listerner "tcp"```
      - Ensure ```tls_disable = "false"```
      - Add ```tls_cert_file = "/etc/vault.d/tls/<vault_node_cert>"```
      - Add ```tls_key_file = "etc/vault.d/tls/<vault_node_key>"```
      - Add ```tls_client_ca_file = "/etc/vault.d/tls/<vault_node_fullchain_cert>"```
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
- Next, we will cover
  - Migrating the consul and vault nodes to use the https scheme
  - Updating our load balancer frontend to use its own certificate so that we can:
    - Serve https traffic to the frontend
    - Terminate the SSL connection at the load balancer
    - Re-encrypt traffic that is sent to the backend clusters
  - Updating Consul Agents and Consul Servers to utilize mTLS and updating the load balancer config to handle this
  - Finally, we will then cover setting up an ACME endpoint for these two intermediate CAs and installing/configuring certbot on each of our nodes for automatic certificate renewal (some deploy hook scripting will be required)