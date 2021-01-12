#!/usr/bin/env bash
if [ -z "$masters" ]; then
  sudo kubeadm init | sudo tee kubeadm-init.log
else
  if [ -z "$pod_network_cidr" ]; then
    sudo kubeadm init --control-plane-endpoint $loadbalancer:$lb_port --upload-certs | sudo tee kubeadm-init.log
  else
    sudo kubeadm init --control-plane-endpoint $loadbalancer:$lb_port \
      --pod-network-cidr $pod_network_cidr --upload-certs | sudo tee kubeadm-init.log
  fi
fi

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sed -i '/source <(kubectl completion bash)/d' ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
