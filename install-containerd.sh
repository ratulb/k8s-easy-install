#!/usr/bin/env bash 

sudo apt update

echo -e "\e[1;42mInstalling cri-containerd...\e[0m"

sudo apt install libseccomp2

rm -rf $HOME/containerd_download/
mkdir $HOME/containerd_download/
wget https://storage.googleapis.com/cri-containerd-release/cri-containerd-$CONTAINERD_VER.linux-amd64.tar.gz -O $HOME/containerd_download/cri-containerd-$CONTAINERD_VER.linux-amd64.tar.gz
sudo tar --no-overwrite-dir -C / -xzf $HOME/containerd_download/cri-containerd-$CONTAINERD_VER.linux-amd64.tar.gz

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Apply sysctl params without reboot
sudo sysctl --system
sudo systemctl start containerd

echo -e "\e[1;42mInstalled cri-containerd...\e[0m"

