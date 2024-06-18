#!/bin/bash

CERTMANANGER_VERSION=v1.15.0
HOSTNAME=rancher.homelab.lan
REPLICA_COUNT=3
BOOTSTRAP_PASSWORD=1234567890

echo "#############################################################################################################################"
echo "This script is intended to be used as a testing template to install rancher and cert-manager and is not production ready."
echo "               This script is using the setup guide from the official documentation located at:"
echo "- https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli."
echo "-----------------------------------------------------------------------------------------------------------------------------"
echo "This script is using the following variables:"
echo "- CERTMANANGER_VERSION=${CERTMANANGER_VERSION}"
echo "- HOSTNAME=${HOSTNAME}"
echo "- REPLICA_COUNT=${REPLICA_COUNT}"
echo "- BOOTSTRAP_PASSWORD=${BOOTSTRAP_PASSWORD}"
echo "If you want to change the values of these variables, please edit the script file."
echo "#############################################################################################################################"

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERTMANANGER_VERSION}/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io

helm repo update

echo "Installing cert-manager"
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace
echo "Waiting for cert-manager to be ready"
kubectl wait --for=condition=available --timeout=600s deployment/cert-manager-webhook -n cert-manager
echo "Cert-manager installation complete."


echo "Installing rancher"
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=${HOSTNAME} \
  --set replicas=${REPLICA_COUNT} \
  --set bootstrapPassword=${BOOTSTRAP_PASSWORD}
echo "Waiting for rancher to be ready"
kubectl wait --for=condition=available --timeout=600s deployment/rancher -n cattle-system
echo "Rancher installation complete."