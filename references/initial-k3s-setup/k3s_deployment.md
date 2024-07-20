
# Using VERSION v1.28.10+k3s1

### If Changes need to be made to an already running server that affects the entire cluster
- Modify the ```/etc/systemd/system/k3s.service``` file and save changes
- Run ```sudo systemctl daemon-reload && sudo systemctl restart k3s```


## Deployment Considerations
- Installing K3S version 1.28.10+k3s1 due to Rancher's current support limit up to this version
- Disabling ```servicelb``` due to using ```metallb``` instead
- Disabling ```traefik``` initially so that we can roll our own ```traefik``` instance, specifically, want to use ```traefik3.0```

---------------------------------------------------------------

## [ Installing First k3s Server On First Master Node ]
- Run
  ```
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.10+k3s1 sh -s - server \
     --tls-san=<X.X.X.X> \
     --tls-san=<load-balancer_or_other_san> \
     --disable traefik \
     --disable servicelb \
     --write-kubeconfig-mode=644 \
     --cluster-init
  ```
- Run ```sudo cat /var/lib/rancher/k3s/server/token``` and copy this token value, this is what will be used in the <token> fields when joining nodes

---------------------------------------------------------------

## [ Installing k3s Server On Subsequent Master Nodes ]
- Run
  ```
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.10+k3s1 sh -s - server \
  --tls-san=X.X.X.X \
  --tls-san=<load-balancer_or_other_san> \
  --token=<token> \
  --server=https://<X.X.X.X>:xxxx \
  --disable servicelb \
  --disable traefik  \
  --write-kubeconfig-mode=644
  ```

---------------------------------------------------------------

## [ Installing k3s Agents On Worker Nodes ]
- Run
  ```
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.10+k3s1 sh -s - agent \
  --token=<token> \
  --server=https://<X.X.X.X>:xxxx
  ```

## Post Cluster Initialization Steps

- Afterwards, run ```export KUBECONFIG=/etc/rancher/k3s/k3s.yaml``` to export the config if memcache errors appear


## Installing Cert-Manager
- Check for the version that is supported on the kubernetes version being run in the cluster [HERE](https://cert-manager.io/docs/releases/)
  - I will be using v1.15.1 as that's the most recent version and it still supports kubernetes v1.28
- Install the CRDs by running ``` kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.crds.yaml```
  - You should see something similar to:
    ```
    customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
    customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
    customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
    customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
    customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
    customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
    ```
- Now to install via helm:
  - The following command will simply install the helm chart in jetstack in the ```cert-manager``` namespace
  - Run
    ```
    helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.15.1 \
    ```
  - You should see the following output:
    ```
    NAME: cert-manager
    LAST DEPLOYED: Thu Jul  4 20:58:48 2024
    NAMESPACE: cert-manager
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    cert-manager v1.15.1 has been deployed successfully!

    In order to begin issuing certificates, you will need to set up a ClusterIssuer
    or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

    More information on the different types of issuers and how to configure them
    can be found in our documentation:

    https://cert-manager.io/docs/configuration/

    For information on how to configure cert-manager to automatically provision
    Certificates for Ingress resources, take a look at the `ingress-shim`
    documentation:

    https://cert-manager.io/docs/usage/ingress/
    ```
  - You can check that it was successfully deployed by running ```kubectl get pods -n cert-manager```
    ```
    $ kubectl get pods -n cert-manager
    NAME                                       READY   STATUS    RESTARTS        AGE
    cert-manager-cainjector-57fd464d97-wxb22   1/1     Running   0               5m5s
    cert-manager-d548d744-p742r                1/1     Running   0               5m5s
    cert-manager-webhook-8656b957f-9g2w7       1/1     Running   0               5m5s
    ```

## Installing MetalLB
- Create the namespace: ```kubectl create namespace metallb-system```
- Add the helm repo with ```helm repo add metallb https://metallb.github.io/metallb```
- As always, update the helm repos to make sure you have the most up to date repos available with ```helm repo update```
- Now to instal MetalLB, run ```helm install metallb metallb/metallb --namespace metallb-system```
  - You should see the following output:
    ```
    $ helm install metallb metallb/metallb --namespace metallb-system
    NAME: metallb
    LAST DEPLOYED: Thu Jul  4 21:23:47 2024
    NAMESPACE: metallb-system
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    MetalLB is now running in the cluster.
    Now you can configure it via its CRs. Please refer to the metallb official docs
    on how to use the CRs.
    ```
- Create a yaml file that will be used to create a DHCP pool for MetalLB to utilize and then an L2Advertise config to advertise the IP addresses in the first config's pool. This can be configured in the same yaml file separated by ```---```, for example, my config looks like so:
    ```
    # Pool of IP addresses that MetalLB can assign to services
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: k3s-pool
      namespace: metallb-system
    spec:
      addresses:
      - 10.243.160.1-10.243.160.63
    ---
    # Advertisement of the IP address pool
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: k3s-pool-advertisement
      namespace: metallb-system
    spec:
      ipAddressPools:
      - k3s-pool
    ```
  - What you'll notice is that I specified 64 IP addresses. In my setup, I have a VLAN on my pfSense with an IP range of 10.243.160.0/24. However, the DHCP server for this VLAN only dishes out IP addresses from 10.243.160.64-10.243.160.254. For MetalLB, you need to have a specified range blocked out for it that won't overlap with the upstream DHCP, hence the X.X.X.1-63 block in the config. You can always change this value as long as you take into consideration your upstream DHCP. MetalLB offers BGP routing as well, but for the sake of simplicity (as well as the fact that I haven't set it up on pfSense yet), we'll be sticking with L2 advertising.
- After creating your config, we need to apply it to the cluster by running ```kubectl apply -f path/to/config/config_name.yaml```
  - You should see the following similar output:
    ```
    $ kubectl apply -f kubernetes/utilities/metallb/values.yaml
    ipaddresspool.metallb.io/k3s-pool created
    l2advertisement.metallb.io/k3s-pool-advertisement created
    ```

## Installing Traefik
-


## Installing Rancher
- Add the rancher repo to helm, we'll be using the stable repo. At the time of writing, this will be version 2.8.5 which supports kubernetes v1.28
  - Run ```helm repo add rancher-stable https://releases.rancher.com/server-charts/stable```
- Then, update the repo with ```helm repo update```
- Create the ```cattle-system``` namespace (this must be named exactly ```cattle-system``` for Rancher to work according to their docs)
  - Run ```kubectl create namespace cattle-system```
- Now we install Rancher - NOTE: the hostname, in this case, will be a local DNS record on my pfSense machine, we will map the DNS record to the IP of the Rancher service later, however, this value can be any valid DNS hostname and mapped to any valid IP address - this just needs to be a valid DNS record for your setup
  ```
  helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.homelab.lan \
  --set replicas=3
  ```
- You should see the following similar output:
  ```
  $    helm install rancher rancher-stable/rancher \
  >     --namespace cattle-system \
  >     --set hostname=rancher.homelab.lan \
  >     --set replicas=3
  NAME: rancher
  LAST DEPLOYED: Thu Jul  4 22:08:48 2024
  NAMESPACE: cattle-system
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
  NOTES:
  Rancher Server has been installed.
  NOTE: Rancher may take several minutes to fully initialize. Please standby while Certificates are being issued, Containers are started and the Ingress rule comes up.
  Check out our docs at https://rancher.com/docs/
  If you provided your own bootstrap password during installation, browse to https://rancher.homelab.lan to get started.
  If this is the first time you installed Rancher, get started by running this command and clicking the URL it generates:
  echo https://rancher.homelab.lan/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')
  To get just the bootstrap password on its own, run:
  kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}'
  Happy Containering!
  ```
- You can check the deployment status by running ```kubectl -n cattle-system rollout status deploy/rancher```