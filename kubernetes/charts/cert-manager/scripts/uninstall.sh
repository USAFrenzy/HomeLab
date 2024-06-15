#!/bin/bash

NAMESPACE="cert-manager"

echo "Uninstalling Cert Manager Helm Release..."
helm uninstall cert-manager --namespace $NAMESPACE
echo "Cert Manager Helm Release Uninstalled."

echo "Deleting ClusterIssuers..."
kubectl delete -f ../issuers/rc-server/letsencrypt-production.yml
kubectl delete -f ../issuers/rc-server/letsencrypt-staging.yml
kubectl delete -f ../issuers/rchomelab/letsencrypt-production.yml
kubectl delete -f ../issuers/rchomelab/letsencrypt-staging.yml
echo "ClusterIssuers Deleted."

echo "Deleting Cert Manager CRDs..."
kubectl delete -f ../install/cert-manager_v1.13.1.crds.yaml
echo "Cert Manager CRDs Deleted."

echo "Deleting Namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE
echo "Namespace $NAMESPACE Deleted."

echo "Cert Manager and All Related Resources Have Been Uninstalled."
