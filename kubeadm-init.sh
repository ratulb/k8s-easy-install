#!/usr/bin/env bash 
sudo apt update
sudo kubeadm init | sudo tee kubeadm-init.log 
sudo chown $(id -u):$(id -g) kubeadm-init.log

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
