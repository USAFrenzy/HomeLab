# Setting Up Consul

## Downloading and Installing Consul
- First update the system and grab prerequisites
  - ```sudo apt update && sudo apt install -y wget unzip```
- Now, set an environment variable for whatever consul version you wish to install (I am currently using 1.20.2)
  - ```CONSUL_VERSION="1.20.2"```
- Next, we're going to grab that version of consul with wget, unzip it, and move it to the bin
  - ```wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip```
  - ```unzip consul_${CONSUL_VERSION}_linux_amd64.zip```
  - ```sudo mv consul /usr/local/bin/```
  - ```sudo chmod +x /usr/local/bin/consul```

## Setting Up Consul User and Directories
- We're now going to add a user that will own the consul directory and files within
  - ```sudo useradd --system --home /etc/consul.d --shell /bin/false consul```
  - ```sudo mkdir -p /etc/consul.d```
  - ```sudo mkdir -p /var/lib/consul```
  - ```sudo chown -R consul:consul /etc/consul.d /var/lib/consul```

## Configuring Consul
- Create a configuration file called consul.hcl under ```/etc/consul.d/```
- The contents of the file should like something like the below excerpt for a simple consul node:
```
bind_addr       = "0.0.0.0"
client_addr     = "0.0.0.0"
data_dir        = "/var/lib/consul"
datacenter      = "dc1"
log_level       = "INFO"
server          = true
ui              = true
bootstrap_expect = 1
```
- The above snippet sets consul up to listen on any interface and receive connections from any client requesting consul.
- We set this instance as a server and enable the UI (you can disable this at any time)
- You can name the ```datacenter``` whatever you'd like, but you must be consistent across all vault and consul node configs
- The ```data_dir``` is just where consul will store its data, this can be any directory, so long as you ```chown``` that directory to ```consul```
- Since we're only working with a single node at the moment, we set ```bootstrap_expect=1```, later on, this will be reconfigured for a clustered environment

<br>

- For a whole picture reference, my current config as of this writing looks like so:
```
node_name       = "consul-01"
bind_addr       = "0.0.0.0"
advertise_addr  = "192.168.20.9"
client_addr     = "0.0.0.0"
data_dir        = "/var/lib/consul"
datacenter      = "dc1"
log_level       = "INFO"
server          = true
ui              = true
bootstrap_expect = 3
ca_file   = "/etc/consul.d/tls/consul-fullchain.pem"
cert_file = "/etc/consul.d/tls/consul-cert.pem"
key_file  = "/etc/consul.d/tls/consul-key.pem"
verify_incoming        = true
verify_outgoing        = true
verify_server_hostname = true
ports {
  http  = 0       # disable plain HTTP
  https = 8501    # enable HTTPS on a new port
}
retry_join = [
  "consul-01.homelab.lan",
  "consul-02.homelab.lan",
  "consul-03.homelab.lan"
]

```
- In the above reference, there are sections that will be added but involve further steps to be completed first.
  - The following will be configured under the ```Issuing Certificates to Vault and Consul``` section:
    - ```ca_file```
    - ```cert_file```
    - ```key_file```
  - The following will be configured under the ```Making Vault And Consul Highly Available``` section
    - ```retry_join=[]```
    - ```advertise_addr```
    - ```bootstrap_expect = 3```
  - The following will be configured under the ```Migrating Consul Agents and Servers to HTTPS``` section
    - ```ports {}```
  - The following will be configured under the ```Setting Up mTLS For Consul``` section
    - ```verify_incoming```
    - ```verify_outgoing```
    - ```verify_server_hostname```


## Setting Up Consul As A Systemd Service and Validating Consul Install
- Create a ```consul.service``` file under ```/etc/systemd/system/consul.service```
- Open that file in an editor and copy the following into that file:
```
[Unit]
Description="HashiCorp Consul"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
- This sets the service up to rely on the networking module for communication and sets the actual service up based on the environment we configured in the first couple of steps
- To enable and run our consul service, we need to first reload the systemctl daemon so it can see the new service, then enable the new service at startup
  - ```sudo systemctl daemon-reload```
  - ```sudo systemctl enable consul```
  - ```sudo systemctl start consul```
- Validate that the new consul service is working without any issues with:
  - ```sudo journalctl -xeu consul -f```
  - ```sudo systemctl status consul```
  - Navigate over to ```http://<console_node_ip_or_FQDN>:8500/ui``` if the UI was enabled in the config with ```ui=true```