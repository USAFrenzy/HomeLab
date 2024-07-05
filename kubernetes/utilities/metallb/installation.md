- This page references [The Official Documentation](https://metallb.universe.tf/installation/)

- Installation by manifest
  - Run ```kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml```
- Create a config yaml to deploy to have metallb start issuing out and advertising IP addresses
  - The one I'm currently using is found under utilities/metallb/values.yaml
  - Disable Klipper (on K3S) by modifying the k3s.service file and appending ```--disable servicelb``` flag on each node
    - Run ```sudo systemctl daemon-reload && sudo systemctl restart k3s``` on each node