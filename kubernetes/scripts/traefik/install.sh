#!/bin/bash

# Set namespace
NAMESPACE="traefik"

# Create namespace if it doesn't exist
kubectl get namespace $NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
  kubectl create namespace $NAMESPACE
fi

# Apply credentials
kubectl apply -f ../config/creds/cf-sealed-creds.yml -n $NAMESPACE
kubectl apply -f ../config/creds/cf-sealed-tls-certs.yml -n $NAMESPACE

# Apply persistent storage
kubectl apply -f ../config/persistent-storage/ssl-cert-pvc.yml -n $NAMESPACE
kubectl apply -f ../config/persistent-storage/ssl-cert-pv.yml -n $NAMESPACE

# Apply RBAC configurations
kubectl apply -f ../config/rbac/0-traefik-service-account.yml -n $NAMESPACE
kubectl apply -f ../config/rbac/1-traefik-ingress-controller-role.yml -n $NAMESPACE
kubectl apply -f ../config/rbac/2-traefik-ingress-controller-role-binding.yml -n $NAMESPACE

# Apply service
kubectl apply -f ../config/service/traefik-service.yml -n $NAMESPACE

# Apply dashboard configurations
kubectl apply -f ../dashboard/001-traefik-dash-sealed-auth.yml -n $NAMESPACE
kubectl apply -f ../dashboard/002-traefik-middleware.yml -n $NAMESPACE
kubectl apply -f ../dashboard/003-default-headers.yml -n $NAMESPACE
kubectl apply -f ../dashboard/004-traefik-ingress-internal.yml -n $NAMESPACE

# Apply deployment configurations
kubectl apply -f ../deployment/traefik-values.yml -n $NAMESPACE

echo "Traefik installation complete."
