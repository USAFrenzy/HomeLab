
sudo mkdir k9s && cd k9s && \
sudo curl -fsSL -o k9s_Linux_amd64.tar.gz https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_Linux_amd64.tar.gz && \
sudo tar -xzf k9s_Linux_amd64.tar.gz && \
sudo cp k9s /usr/local/bin/k9s