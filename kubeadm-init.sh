#!/usr/bin/env bash
masters=#masters#
pod_network_cidr=#pod_network_cidr#
loadbalancer=#loadbalancer#
lb_port=#lb_port#

sudo systemctl restart kubelet
_advertise_address=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
if [ -z "$_advertise_address" ]; then
  _advertise_address=$(hostname -I | awk '{print $1}')
fi
if [ -z "$loadbalancer" ]; then
  sudo kubeadm init --token-ttl 0 --apiserver-advertise-address $_advertise_address | tee kubeadm-init.log
else
  if [ -z "$pod_network_cidr" ]; then
    sudo kubeadm init --token-ttl 0 --control-plane-endpoint $loadbalancer:$lb_port --apiserver-advertise-address $_advertise_address --upload-certs | tee kubeadm-init.log
  else
    sudo kubeadm init --token-ttl 0 --control-plane-endpoint $loadbalancer:$lb_port --apiserver-advertise-address $_advertise_address --pod-network-cidr $pod_network_cidr --upload-certs | tee kubeadm-init.log
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
