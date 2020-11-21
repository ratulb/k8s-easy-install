#!/usr/bin/env bash 
sudo scp $1:~/kubeadm-init.log .
mkdir -p $HOME/.kube
sudo scp $1:~/.kube/config  $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
