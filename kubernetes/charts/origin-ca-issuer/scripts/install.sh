#!/bin/bash

# Set namespace
NAMESPACE="origin-ca-issuer"

# Create namespace if it doesn't exist
kubectl get namespace $NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
  kubectl create namespace $NAMESPACE
fi

# Apply the necessary manifests
kubectl apply -f ../crds/cert-manager.k8s.cloudflare.com_originissuers.yaml -n $NAMESPACE
kubectl apply -f ../certs/origin-cert-rc-server.yml -n $NAMESPACE
kubectl apply -f ../certs/origin-cert-rc-homelab.yml -n $NAMESPACE
kubectl apply -f ../origin-issuer/origin-issuer-secret.yml -n $NAMESPACE
kubectl apply -f ../origin-issuer/origin-issuer.yml -n $NAMESPACE

echo "Installation complete."
