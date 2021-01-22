#!/usr/bin/env bash
masters=#masters#
pod_network_cidr=#pod_network_cidr#
loadbalancer=#loadbalancer#
lb_port=#lb_port#

process_name=$(sudo ss -lptn 'sport = :6443' | cut -d'"' -f2)
process_id=$(sudo ss -lptn 'sport = :6443' | grep pid | cut -d'=' -f2 | cut -d',' -f1)
sudo systemctl stop $process_name &>/dev/null
#sudo systemctl disable $process_name &>/dev/null
#sudo systemctl daemon-reload
sudo kill -9 $process_id &>/dev/null

sudo systemctl restart kubelet
if [ -z "$loadbalacer" ]; then
  sudo kubeadm init --token-ttl 0 --cri-socket /run/containerd/containerd.sock | sudo tee kubeadm-init.log
else
  if [ -z "$pod_network_cidr" ]; then
    sudo kubeadm init --token-ttl 0 --cri-socket /run/containerd/containerd.sock --control-plane-endpoint $loadbalancer:$lb_port --upload-certs | sudo tee kubeadm-init.log
  else
    sudo kubeadm init --token-ttl 0 --cri-socket /run/containerd/containerd.sock --control-plane-endpoint $loadbalancer:$lb_port --pod-network-cidr $pod_network_cidr --upload-certs | sudo tee kubeadm-init.log
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
