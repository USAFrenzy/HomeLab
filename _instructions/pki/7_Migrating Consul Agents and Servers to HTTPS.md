# Migrating Consul Agents and Servers To HTTPS

- First, we need to create a certificate for the entry point on our load balancer so that when we send the request to our entry point, it's encrypted and then subsequently terminated at the load balancer before being re-encrypted and sent to our backend clusters.
- In a similar manner to how we set up the consul and vault intermediate CAs, we're going to set up another intermediate CA for all of our load balancer related certificates.
- Following the same procedure we used in the ```Setting Up An Intermediate CA``` section of ```Creating PKI Secrets Engines```, create a ```pki-loadbalancer``` engine
- Once set up, configure the engine for the ```AIA``` path, ```Cluster path```, and the Global URLs for ```Isssuing```, ```CRL```, and ```OCSP```.
- Populate all SAN related fields for ```Allowed Domains``` and the ```Additional SANs Options``` fields
- Tune this engine to your preference for things like key usage and TTL, ensure that ```Server Auth``` and ```Client Auth``` are enabled in key usage
- Create separate roles for each load balancer endpoint, or optionally, create a role to issue wildcard certificates
- On the role you have created, generate a certificate for the entrypoint you specified for vault and consul (whether this is using a wildcard role or two separate roles)
- Save the leaf certificates and private keys for each.
- Create a full chain certificate that includes the private key (this is necessary for terminating the connection at the load balancer and re-encrypting the connection)
  - The combined full chain certificate should contain, in this order:
    - The private key
    - The leaf certificate
    - The load balancer intermediate CA certificate
    - The root CA's certificate (this is the CA that signed the CSR for the load balancer CA)
  - Copy this combined certificate over to the load balancer and place it under ```/etc/haproxy/certs```
- Next, we need the Intermediate CA certificate and Root CA certificate to form a CA chain for the backends
  - Create this combined chain file for vault and another for consul
  - Place these combined files in ```/etc/haproxy/ca``` and name them something logical
- Finally, for consul to trust our load balancer, we need to present our load balancer certificate chain on consul's backend (this is in preparation for mTLS)
  - Similar to what we did for the entrypoint combined certificate, we will now create a full chain for the load balancer itself
  - On the load balancer pki engine, create a certificate that covers the load balancer host and IP address
    - Save the resulting certificates and private key somewhere safe
    - Create the full chain certificate to be used:
      - The load balancer node's private key
      - The load balancer node's leaf certificate
      - The load balancer Intermediate CA certificate
      - The root CA's certificate (the one that signed the load balancer Intermediate CA)
    - Copy this full chain certificate over to ```/etc/haproxy/certs```
- We now have all the certificates that we need to make this next step work
- On the load balancer, modify the frontend to use the entrypoint certs. Since we're using multiple, we can just state the directory that the certs are in
```
...
bind *:443 ssl crt /etc/haproxy/certs
...
```
- Next, on Vault's backend, modify the lines to check ssl and use the CA chain file we created to verify the certificate presented
```
...
server vault-01 X.X.X.X:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem
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
    default_backend truenas_backend

backend no_route
    mode http
    errorfile 503 /etc/haproxy/errors/503.http

backend vault_backend
    mode http
    balance roundrobin
    option httpchk GET /v1/sys/health
    server vault-01 192.168.20.6:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem
    server vault-02 192.168.20.7:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem
    server vault-03 192.168.20.8:8200 check ssl verify required ca-file /etc/haproxy/ca/pki-vault-chain.pem

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
  - Next, on the vault nodes, restart the consul service
    - Ensure that the agents successfully reach out and communicate with the cluster
  - Ensure that on all nodes, there are no issues


### Setting up mTLS For Consul
- We already did the major legwork for this earlier up with the certificate issuance
- Now that all consul services are communicating over https, we just need to edit the config once more and restart consul
- In each node's ```consul.hcl``` file, add the following lines:
  - ```verify_incoming = true```
  - ```verify_outgoing = true```
  - ```verify_server_hostname = true```
- Restart each consul service; mTLS is now enabled for the consul service - we now require certificates to be presented to consul in order for communication to occur with the consul cluster and consul nodes going forward

<br>
<br>

## In Sumamary, We Have Now Secured Our Frontend And Backends
- Our traffic is encryted from our device to our load balancer
- The load balancer terminates the SSL connection using the certs we provided for our entrypoints
- The load balancer matches the incoming host SNI to a backend and forwards the traffic to the appropriate backend
- The traffic is re-encrypted as it's sent to the backends
- In terms of consul, the load balancer presents its own certificate to establish a chain of trust for mTLS
- For both backends, we require that each node can verify the chain of trust from the load balancer to the nodes