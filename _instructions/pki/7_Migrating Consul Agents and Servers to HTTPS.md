# Migrating Consul Agents and Servers To HTTPS

- In the previous section, we created all of the certificates we would need and distributed them, now we will make full use of those certificates and trnasfer over to using solely https.
- On the load balancer, modify the frontend to use the entrypoint certs. Since we're using multiple, we can just state the directory that the certs are in
```
...
bind *:443 ssl crt /etc/haproxy/certs
...
```
- Next, on Vault's backend, modify the lines to check ssl and use the CA chain file we created to verify the certificate presented
```
...
server vault-01 X.X.X.X:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem
...
```
- Similarlly, we modify Consul's backend to do the same. However, we're also going to be presenting the load balancer node's full chain certificate for the mTLS
```
...
server consul-01 192.168.20.9:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem
...
```
- All together, the ```haproxy.cfg``` file should look something like:
``` cfg
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs
    mode http
    # Frontends
    acl vault_frontend hdr(host) -i vault.homelab.lan
    acl consul_frontend hdr(host) -i consul.homelab.lan
    # Backends
    use_backend vault_backend if vault_frontend
    use_backend consul_backend if consul_frontend
    # Default Backend
    default_backend no_route

backend no_route
    mode http
    errorfile 503 /etc/haproxy/errors/503.http

backend vault_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/sys/health
    server vault-01 192.168.20.6:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem
    server vault-02 192.168.20.7:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem
    server vault-03 192.168.20.8:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem

backend consul_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/status/leader
    server consul-01 192.168.20.9:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem
    server consul-02 192.168.20.10:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem
    server consul-03 192.168.20.11:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem crt /etc/haproxy/certs/pki-lb-chain.pem

```

- Now, we need to update the ```consul.hcl``` on the vault nodes and on the consul nodes:
  - On each node, edit the ```/etc/consuld.consul.hcl``` file and add:
```
ports {
  http  = 0       # disable plain HTTP
  https = 8501    # enable HTTPS on a new port
}
```
  - On the consul nodes, restart the consul service: ```sudo systemctl restart consul```
    - Ensure that the cluster starts successfully and that all of the server nodes rejoin the cluster
    - There will be statements in the logs referencing the use of http on https or the lack of TLS certs on an http port
      - This is safe to ignore for the moment due to not having restarted the Vault nodes' consul service yet
  - Next, on the vault nodes:
    - Edit the ```vault.hcl``` config to include the following line in the ```storage "consul"``` block:
      - ```scheme = "https"```
      - Ensure that the ```address =``` line points to the https port that is being configured for the consul agents and servers
    - Restart the consul service
    - Ensure that the agents successfully reach out and communicate with the cluster
  - Ensure that on all nodes, there are no issues


## Hardening Our Nodes

- Setting up mTLS on our consul nodes
  - We already did the major legwork for this earlier up with the certificate issuance
  - Now that all consul services are communicating over https, we just need to edit the config once more and restart consul
  - In each node's ```consul.hcl``` file, add the following lines:
    - ```verify_incoming = true```
    - ```verify_outgoing = true```
    - ```verify_server_hostname = true```
  - Restart each consul service; mTLS is now enabled for the consul service - we now require certificates to be presented to consul in order for communication to occur with the consul cluster and consul nodes going forward
  - If you see logs for rejecting a lock, this is totally normal as consul uses this mechanism to prevent race conditions (very similar to a mutex)
- Now that we've verified that our nodes are communicating over https and that mTLS has successfully been deployed, we should harden the communication traffic a bit more.
  - In all ```consul.hcl``` config files, add the following lines:
```
tls_min_version       = "TLSv1_3"
```
- This config should now look something like:
```
node_name       = "consul-03"
bind_addr       = "0.0.0.0"
advertise_addr  = "192.168.20.11"
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
tls_min_version       = "TLSv1_3"
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
  - In all ```vault.hcl``` config files, add the following line inside the ```listener "tcp"``` block:
```
tls_min_version       = "TLSv1_3"
# This allows us to receive the real client's IP address accessing our entrypoint
proxy_protocol_behavior = "use_always"
# These are the IP Addresses of the load balancer - this is required with proxy protocol
proxy_protocol_authorized_addrs = [
"192.168.20.3",
"192.168.20.4",
"192.168.20.5"
]
```
  - Next, add a secondary tcp listener with the same settings as the first, minus the proxy options, on a port of your choice (port 8201 here). This port will solely be used for health checks on haproxy:
```
listener "tcp" {
  address       = "0.0.0.0:8201"
  tls_cert_file = "/etc/vault.d/tls/vault-03_cert.pem"
  tls_key_file  = "/etc/vault.d/tls/vault-03_key.pem"
  tls_client_ca_file = "/etc/vault.d/tls/lb-ca-chain.pem"
  tls_min_version = "tls13"
}

```
- This config should now look something like:
```
ui = true
api_addr = "https://vault-03.homelab.lan:8200"
cluster_addr = "https://192.168.20.8:8200"

listener "tcp" {
  address       = "0.0.0.0:8200"
  proxy_protocol_behavior = "use_always"
  proxy_protocol_authorized_addrs = [
  "192.168.20.3",
  "192.168.20.4",
  "192.168.20.5"
  ]
  tls_cert_file = "/etc/vault.d/tls/vault-03_cert.pem"
  tls_key_file  = "/etc/vault.d/tls/vault-03_key.pem"
  tls_client_ca_file = "/etc/vault.d/tls/lb-ca-chain.pem"
  tls_min_version = "tls13"
}
listener "tcp" {
  address       = "0.0.0.0:8201"
  tls_cert_file = "/etc/vault.d/tls/vault-03_cert.pem"
  tls_key_file  = "/etc/vault.d/tls/vault-03_key.pem"
  tls_client_ca_file = "/etc/vault.d/tls/lb-ca-chain.pem"
  tls_min_version = "tls13"
}
storage "consul" {
  address = "192.168.20.8:8501"
  scheme  = "https"
  tls_ca_file    = "/etc/consul.d/tls/consul-fullchain.pem"
  tls_cert_file  = "/etc/consul.d/tls/consul-cert.pem"
  tls_key_file   = "/etc/consul.d/tls/consul-key.pem"
  path    = "vault/"
}

```
  - On your firewall, ensure that the only thing that can communicate on your health check port is/are the load balancer(s)
    - Allow the load balancer(s) to pass traffic to your vault nodes at port 8201
    - Block all other communication to your vault nodes at port 8201
  - On the load balancer's config, edit the frontend and the backend to use TLSv1.3 as well by adding ```ssl-min-ver TLSv1.3```:
  - On the vault backend, we are going to heavily modify the connections to vault
    - We will create a new backend solely for health checks
    - We will modify the production backend to track the health checks in the health check backend
    - This separation is what ended up working best for interaction with vault and haproxy
``` cfg
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs ssl-min-ver TLSv1.3
    mode http
    # Frontends
    acl vault_frontend hdr(host) -i vault.homelab.lan
    acl consul_frontend hdr(host) -i consul.homelab.lan
    # Backends
    use_backend vault_backend if vault_frontend
    use_backend consul_backend if consul_frontend
    # Default Backend
    default_backend no_route

backend no_route
    mode http
    errorfile 503 /etc/haproxy/errors/503.http

backend vault_health
    mode http
    # checks whether it's a healthy active node, marking standby as down (unroutable)
    option httpchk GET /v1/sys/health?standbyok=false
    # returns either OK if the above check resulted in the active node
    http-check expect rstatus 200
    # For each of these, we are sending an un-proxied connection to the second tcp listener (port 8201) and forwarding the SNI of each node. We enforce TLS 1.3 and present the load balancer ca chain to the node
    # that will be verified and matched with the ca chain we provided in vault's config on tls_client_ca_file.
    server vault-01 192.168.20.6:8201 ssl check no-send-proxy check-sni vault-01.homelab.lan verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem
    server vault-02 192.168.20.7:8201 ssl check no-send-proxy check-sni vault-02.homelab.lan verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem
    server vault-03 192.168.20.8:8201 ssl check no-send-proxy check-sni vault-03.homelab.lan verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem

backend vault_backend
    mode http
    balance roundrobin
    # For each server, we now send the proxy header to allow vault to glean the actual client's IP address - this can be used for restricting access based on token restrictions. Just like with the health check above, we forward
    # the SNI of each node and enforce TLS 1.3 while presenting the load balancer ca chain to the node that will be verified and matched with the ca chain we provided in vault's config on tls_client_ca_file. We add the source
    # directive to essentially forward the IP address that hit our aliased entrypoint and allow vault to parse this proxy header from a trusted source (the IP address we configured in vault's config)
    server vault-01 192.168.20.6:8200 send-proxy source load-balancer.homelab.lan track vault_health/vault-01 ssl sni str("vault-01.homelab.lan") verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem
    server vault-02 192.168.20.7:8200 send-proxy source load-balancer.homelab.lan track vault_health/vault-02 ssl sni str("vault-02.homelab.lan") verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem
    server vault-03 192.168.20.8:8200 send-proxy source load-balancer.homelab.lan track vault_health/vault-03 ssl sni str("vault-03.homelab.lan") verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem

backend consul_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/status/leader
    # Not much is changed here except for enforcing TLS 1.3 noe
    server consul-01 192.168.20.9:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem
    server consul-02 192.168.20.10:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem
    server consul-03 192.168.20.11:8501 check ssl verify required ca-file /etc/haproxy/ca/pki-consul-chain.pem ssl-min-ver TLSv1.3 crt /etc/haproxy/ca/pki-lb-chain.pem

```
- Restart consul agents and servers on all nodes
- Restart vault service on vault nodes
- Restart load balancer service on all applicable nodes
- Ensure that consul nodes rejoin cluster
- Ensure vault nodes successfully start and that their consul agents are communicating with the consul servers
- Ensure your load balancer service starts
- Unseal the vault nodes -> profit

<br>

- Last but not least, let's enable auditing - we set up client ip address proxy forwarding, so we should enable auditing anyways to take advantage of that.
  - On the active vault node (this will be replicated to the other nodes when not in standby):
    - Run ```export VAULT_ADDR=https://vault.homelab.lan``` - use your entrypoint
    - Run ```export VAULT_CACERT=/etc/vault.d/tls/<vault_node>_fullchain.crt```
    - Create the log file: ```sudo touch /var/log/vault_audit.log```
    - Give vault ownership: ```sudo chown vault:vault /var/log/vault_audit.log```
    - Then restrict permissions to the file: ```sudo chmod 640 /var/log/vault_audit.log```
    - Finally, run: ```vault audit enable file file_path=/var/log/vault_audit.log```
  - With that, auditing is now enabled on our vault cluster

<br>
<br>

## In Summary, We Have Now Secured Our Frontend And Backends
- Our traffic is encrypted from our device to our load balancer
- The load balancer terminates the SSL connection using the certs we provided for our entrypoints
- The load balancer matches the incoming host SNI to a backend and forwards the traffic to the appropriate backend
- The traffic is re-encrypted as it's sent to the backends
- In terms of consul, the load balancer presents its own certificate to establish a chain of trust for mTLS
- For both backends, we require that each node can verify the chain of trust from the load balancer to the nodes
- Throughout the chain, we enforce the more secure TLS 1.3 protocol
- We have separated out our backends to allow un-proxied health checks that determine whether or not the node is valid for communication and we track that status in the proxied backend
- We are now able to restrict users and tokens to specific IP addresses for more granular control of access by passing a proxy header
  - We can now use policies that are more restrictive in tandem with restricting the IP CIDR ranges for each token
