#!/usr/bin/env bash 
mkdir -p ~/.kube/
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1:~/.kube/config  ~/.kube/config-$master
chown $(id -u):$(id -g) ~/.kube/config
sed -i '/source <(kubectl completion bash)/d'  ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc

