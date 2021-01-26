#!/usr/bin/env bash
masters=#masters#
pod_network_cidr=#pod_network_cidr#
loadbalancer=#loadbalancer#
lb_port=#lb_port#

sudo systemctl restart kubelet
if [ -z "$loadbalancer" ]; then
  sudo kubeadm init --token-ttl 0 | tee kubeadm-init.log
else
  if [ -z "$pod_network_cidr" ]; then
    sudo kubeadm init --token-ttl 0 --control-plane-endpoint $loadbalancer:$lb_port --upload-certs | tee kubeadm-init.log
  else
    sudo kubeadm init --token-ttl 0 --control-plane-endpoint $loadbalancer:$lb_port --pod-network-cidr $pod_network_cidr --upload-certs | tee kubeadm-init.log
  fi
fi

if [ -s /etc/kubernetes/admin.conf ]; then
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  sed -i '/source <(kubectl completion bash)/d' $HOME/.bashrc
  echo 'source <(kubectl completion bash)' >>$HOME/.bashrc
  source $HOME/.bashrc
fi
