#!/usr/bin/env bash 
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1:~/kubeadm-init.log .
mkdir -p $HOME/.kube
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1:~/.kube/config  $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
