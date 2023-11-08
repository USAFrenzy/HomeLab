
echo Installing Cert Manager CRDs For Version Cer-Manager 1.13.1...
kubectl apply -f cert-manager_v1.13.1.crds.yaml
echo Cert Manager CRDs Installed.

echo Installing Cert Manager Deployment Via Helm Using Config File 'values.yml' For Cert Manager Version 1.13.1...
helm install cert-manager jetstack/cert-manager --namespace cert-manager --values=values.yml --version v1.13.1
echo Cert Manager Installed And Deployed.