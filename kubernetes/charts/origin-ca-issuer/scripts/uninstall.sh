#!/bin/bash

# Set namespace
NAMESPACE="origin-ca-issuer"

# Delete the manifests
kubectl delete -f ../origin-issuer/origin-issuer.yml -n $NAMESPACE
kubectl delete -f ../origin-issuer/origin-issuer-secret.yml -n $NAMESPACE
kubectl delete -f ../certs/origin-cert-rc-homelab.yml -n $NAMESPACE
kubectl delete -f ../certs/origin-cert-rc-server.yml -n $NAMESPACE
kubectl delete -f ../crds/cert-manager.k8s.cloudflare.com_originissuers.yaml -n $NAMESPACE

# Delete the namespace if it's empty
kubectl get namespace $NAMESPACE -o json | jq -r '.items[0].status.phase' | grep -q "Active"
if [ $? -eq 0 ]; then
  echo "Deleting namespace $NAMESPACE..."
  kubectl delete namespace $NAMESPACE
fi

echo "Uninstallation complete."
