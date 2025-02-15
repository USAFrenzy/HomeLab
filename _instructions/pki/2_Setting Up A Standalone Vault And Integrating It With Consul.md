# Setting Up Vault

## Downloading and Installing Vault
- If you didn't already go through setting up a dedicated consul machine before this step, run:
  - ```sudo apt update && sudo apt install -y wget unzip```
- Now, set an environment variable for whatever Vault version you wish to install (I am currently using 1.18.3)
  - ```VAULT_VERSION="1.18.3"```
- Next, we're going to grab that version of consul with wget, unzip it, and move it to the bin
  - ```wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip```
  - ```unzip vault_${VAULT_VERSION}_linux_amd64.zip```
  - ```sudo mv vault /usr/local/bin/```
  - ```sudo chmod +x /usr/local/bin/vault```

## Setting Up Vault User and Directories
- We're now going to add a user that will own the vault directory and files within
  - ```sudo useradd --system --home /etc/vault.d --shell /bin/false vault```
  - ```sudo mkdir -p /etc/vault.d```
  - ```sudo mkdir -p /var/lib/vault```
  - ```sudo chown -R vault:vault /etc/vault.d /var/lib/vault```

## Configuring Vault
- Create a configuration file called vault.hcl under ```/etc/vault.d/```
- The contents of the file should like something like the below excerpt for a simple vault node:
```
ui = true

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "false"
  tls_cert_file = "/etc/vault.d/vault.crt"
  tls_key_file  = "/etc/vault.d/vault.key"
}

storage "consul" {
  address = "consul-01.homelab.lan:8500"
  path    = "vault/"
}
```
  - Note: Vault requires TLS for the clipboard function. When initially installing vault, it should automatically create the cert and key. If you run into any issues with this, come back in here and set ```tls_disable="true"``` and comment out the ```tls_``` fields. This will disable the TLS enforcement and allow an insecure context for initial setup. You can always create your own certs for vault using vault's very own secrets engine if you decide to as well (this is what I ended up doing).
- The above very basic snippet sets vault to listen on any interface on port ```8200``` and we've set the storage backend to point to our dedicated consul node using the FQDN (this can also be the IP) of the consul node as well as the default http port.
- The ```path``` variable can be anything, it's pretty common to just name it vault since this is for vault anyways

<br>

- Just like when installing consul, I'll provide what my current vault config as of this writing looks like as a reference:
```
ui = true
api_addr = "https://vault-01.homelab.lan:8200"
cluster_addr = "https://192.168.20.6:8200"


listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "false"
  tls_cert_file = "/etc/vault.d/tls/vault-01_cert.pem"
  tls_key_file  = "/etc/vault.d/tls/vault-01_key.pem"
  tls_client_ca_file = "/etc/vault.d/tls/vault-01.fullchain.crt"
}

storage "consul" {
  address = "192.168.20.6:8501"
  scheme  = "https"
  tls_ca_file    = "/etc/consul.d/tls/consul-fullchain.pem"
  tls_cert_file  = "/etc/consul.d/tls/consul-cert.pem"
  tls_key_file   = "/etc/consul.d/tls/consul-key.pem"
  path    = "vault/"
}
```
  - NOTE: You'll notice that this looks pretty vastly different than the simple setup above. A good majority of the changes are due to how we configure a highly available vault and consul cluster; for instance, the fact the consul section points to the same vault node we're running vault off of. That portion is due to installing consul on the vault nodes as well to act as local agents (not servers) that reach out to the consul cluster backend.

## Setting Up Vault As A Systemd Service and Validating Vault Install
- Create a ```vault.service``` file under ```/etc/systemd/system/vault.service```
- Open that file in an editor and copy the following into that file:
```
[Unit]
Description="HashiCorp Vault"
Documentation=https://www.vaultproject.io/
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ProtectHome=read-only
PrivateTmp=yes
ProtectSystem=full
Capabilities=CAP_IPC_LOCK+ep
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
- To enable and run our vault service, we need to first reload the systemctl daemon so it can see the new service, then enable the new service at startup
  - ```sudo systemctl daemon-reload```
  - ```sudo systemctl enable vault```
  - ```sudo systemctl start vault```
- Validate that the new vault service is working without any issues with:
  - ```sudo journalctl -xeu vault -f```
  - ```sudo systemctl status vault```


## Unsealing and Logging Into Vault
- When initializing the vault node, we first need to set it up on the cli
- We need to create an environment variable to set the address of our vault node:
  - ```export VAULT_ADDR="http://<vault_node_ip>:8200"```
- Next, we need to initialize the vault node:
  -  ```vault operator init```
      -  Save the unseal keys and the root token, without these, you basically lose all access to vault. Vault requires the keys every time it has been either manually sealed or when the vault service has been restarted.
- Next, we use a portion of these keys (default key threshold is 3 keys) to unseal vault:
  - ```vault operator unseal <key1>``` - repeat this with 2 more keys
- Now that vault has been unsealed, we can now login with the root token
  - ```vault login <root_token>```
- We can now check the status of the node with
  - ```vault status```
- Finally, we should be able to navigate over to ```http://<vault_node_ip_or_FQDN>:8500/ui``` if the UI was enabled in the config with ```ui=true```