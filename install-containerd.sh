#!/usr/bin/env bash 

sudo apt update

echo -e "\e[1;42mInstalling cri-containerd...\e[0m"

sudo apt install libseccomp2

rm -rf $HOME/containerd_download/
mkdir $HOME/containerd_download/
wget -q https://storage.googleapis.com/cri-containerd-release/cri-containerd-cni-1.3.4.linux-amd64.tar.gz -O $HOME/containerd_download/cri-containerd-cni-1.3.4.linux-amd64.tar.gz
sudo tar --no-overwrite-dir -C / -xzf $HOME/containerd_download/cri-containerd-cni-1.3.4.linux-amd64.tar.gz

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

#cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/0-containerd.conf

#[Service]
#Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"

#EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Apply sysctl params without reboot
sudo sysctl --system
sudo systemctl daemon-reload
sudo systemctl restart containerd

echo -e "\e[1;42mInstalled cri-containerd...\e[0m"

