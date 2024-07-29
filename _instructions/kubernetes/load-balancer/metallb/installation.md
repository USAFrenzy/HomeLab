- This page references [The Official Documentation](https://metallb.universe.tf/installation/)

- Installation by manifest
  - Run ```kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml```
  - If on K3S:
    - Disable Klipper (on K3S) by modifying the k3s.service file and appending ```--disable servicelb``` flag on each node
      - Run ```sudo systemctl daemon-reload && sudo systemctl restart k3s``` on each node

- I am reworking my clusters, so right not I'm only installing this on my K8S cluster (no K3S cluster) with Calico CNI in BGP
  - Since we only need the metallb controller for this setup, remove the speaker pods with: ```kubectl delete daemonset -n metallb-system speaker```
  - For *EVERY* control plane node, run ```kubectl label node <control_node> node.kubernetes.io/exclude-from-external-load-balancers=true --overwrite=true```
    - We do this step because we only want the services and pods on the worker nodes to be load-balanced, not necessarily the control nodes themselves
- Create a config yaml to deploy to have metallb start issuing out and advertising IP addresses
  - The one I'm currently using is found under utilities/metallb/metallb-config1.yaml