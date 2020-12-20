#!/usr/bin/env bash 

sudo kubeadm init | sudo tee kubeadm-init.log 
sudo chown $(id -u):$(id -g) kubeadm-init.log

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sed -i '/source <(kubectl completion bash)/d'  ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
