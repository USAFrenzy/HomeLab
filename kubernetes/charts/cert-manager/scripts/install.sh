#!/bin/bash

NAMESPACE="cert-manager"

echo "Checking if namespace $NAMESPACE exists..."
if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
  echo "Namespace $NAMESPACE already exists."
else
  echo "Creating namespace $NAMESPACE..."
  kubectl create namespace $NAMESPACE
  echo "Namespace $NAMESPACE created."
fi

echo "Installing Cert Manager CRDs For Version Cert-Manager 1.13.1..."
kubectl apply -f ../install/cert-manager_v1.13.1.crds.yaml
echo "Cert Manager CRDs Installed."

echo "Installing Cert Manager Deployment Via Helm Using Config File 'values.yml' For Cert Manager Version 1.13.1..."
helm install cert-manager jetstack/cert-manager --namespace $NAMESPACE --values=../install/values.yml --version v1.13.1
echo "Cert Manager Installed And Deployed."

echo "Applying ClusterIssuers..."
kubectl apply -f ../issuers/rc-server/letsencrypt-production.yml
kubectl apply -f ../issuers/rc-server/letsencrypt-staging.yml
kubectl apply -f ../issuers/rchomelab/letsencrypt-production.yml
kubectl apply -f ../issuers/rchomelab/letsencrypt-staging.yml
echo "ClusterIssuers Applied."
