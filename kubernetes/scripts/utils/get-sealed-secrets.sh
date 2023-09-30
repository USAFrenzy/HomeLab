sudo mkdir sealed-secrets-tmp
cd sealed-secrets-tmp
sudo curl -fsSL -o kubeseal-0.24.0-linux-amd64.tar.gz https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
sudo tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/kubeseal
cd ..
sudo rm -r sealed-secrets-tmp
