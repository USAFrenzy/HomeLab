
Using VERSION v1.28.10+k3s1

---------------------------------------------------------------

- [ Installing First k3s Server On First Master Node ]
  - Run ```curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.10+k3s1 sh -s - server --tls-san=<X.X.X.X> --tls-san=load-balancer.homelab.lan --token=<token> --write-kubeconfig-mode=755 --cluster-init```

---------------------------------------------------------------

- [ Installing k3s Server On Subsequent Master Nodes ]
  - Run ```curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.10+k3s1 sh -s - server --tls-san=X.X.X.X --tls-san=load-balancer.homelab.lan --token=<token> --server=https://<X.X.X.X>:xxxx --write-kubeconfig-mode=755```

---------------------------------------------------------------

- [ Installing k3s Agents On Worker Nodes ]
  - Run ```curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.10+k3s1 sh -s - agent --token=<token> --lb-server-port=8444 --server=https://<X.X.X.X>:xxxx```

- Then run ```curl -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl```
- Then run ```sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl```