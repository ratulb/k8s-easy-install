#!/usr/bin/env bash 

sudo apt update

echo -e "\e[1;32mInstalling cri-containerd-cni.\e[0m"

sudo systemctl stop containerd
sudo systemctl disable containerd
sudo rm -rf /etc/systemd/system/containerd.service 
sudo systemctl daemon-reload

sudo apt install libseccomp2

rm -rf $HOME/containerd_download/
mkdir $HOME/containerd_download/

wget -q https://storage.googleapis.com/cri-containerd-release/cri-containerd-cni-#CONTAINERD_VER#.linux-amd64.tar.gz -O $HOME/containerd_download/cri-containerd-cni-#CONTAINERD_VER#.linux-amd64.tar.gz
sudo tar --no-overwrite-dir -C / -xzf $HOME/containerd_download/cri-containerd-cni-#CONTAINERD_VER#.linux-amd64.tar.gz

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Apply sysctl params without reboot
sudo sysctl --system
sudo systemctl daemon-reload
sudo systemctl start containerd
sudo systemctl enable containerd

echo -e "\e[1;32mInstalled cri-containerd-cni.\e[0m"

