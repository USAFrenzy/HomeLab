#!/bin/bash

# Set namespace
NAMESPACE="traefik"

# Delete deployment configurations
kubectl delete -f ../deployment/traefik-values.yml -n $NAMESPACE

# Delete dashboard configurations
kubectl delete -f ../dashboard/004-traefik-ingress-internal.yml -n $NAMESPACE
kubectl delete -f ../dashboard/003-default-headers.yml -n $NAMESPACE
kubectl delete -f ../dashboard/002-traefik-middleware.yml -n $NAMESPACE
kubectl delete -f ../dashboard/001-traefik-dash-sealed-auth.yml -n $NAMESPACE

# Delete service
kubectl delete -f ../config/service/traefik-service.yml -n $NAMESPACE

# Delete RBAC configurations
kubectl delete -f ../config/rbac/2-traefik-ingress-controller-role-binding.yml -n $NAMESPACE
kubectl delete -f ../config/rbac/1-traefik-ingress-controller-role.yml -n $NAMESPACE
kubectl delete -f ../config/rbac/0-traefik-service-account.yml -n $NAMESPACE

# Delete persistent storage
kubectl delete -f ../config/persistent-storage/ssl-cert-pv.yml -n $NAMESPACE
kubectl delete -f ../config/persistent-storage/ssl-cert-pvc.yml -n $NAMESPACE

# Delete credentials
kubectl delete -f ../config/creds/cf-sealed-tls-certs.yml -n $NAMESPACE
kubectl delete -f ../config/creds/cf-sealed-creds.yml -n $NAMESPACE

# Delete namespace if it's empty
kubectl get namespace $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep -q "Active"
if [ $? -eq 0 ]; then
  echo "Deleting namespace $NAMESPACE..."
  kubectl delete namespace $NAMESPACE
fi

echo "Traefik uninstallation complete."
