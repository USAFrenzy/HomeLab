#!/bin/bash

CERTMANANGER_VERSION="v1.15.0"

helm uninstall cert-manager --namespace cert-manager
helm uninstall rancher --namespace cattle-system

kubectl delete namespace cattle-system
kubectl delete namespace cert-manager

helm repo remove jetstack https://charts.jetstack.io
helm repo remove rancher-latest https://releases.rancher.com/server-charts/latest

kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/${CERTMANANGER_VERSION}/cert-manager.crds.yaml