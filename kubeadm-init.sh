#!/usr/bin/env bash
masters=#masters#
pod_network_cidr=#pod_network_cidr#
loadbalancer=#loadbalancer#
lb_port=#lb_port#

sudo systemctl restart kubelet
_advertise_address=$(hostname -I | awk '{print $1}')
if [ -z "$_advertise_address" ]; then
  _advertise_address=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null)
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

  # When launched under sudo, also install the kubeconfig into the invoking user's home.
  if [ -n "${SUDO_USER:-}" ]; then
    _user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -n "$_user_home" ] && [ "$_user_home" != "$HOME" ]; then
      sudo mkdir -p "$_user_home/.kube"
      sudo cp -i /etc/kubernetes/admin.conf "$_user_home/.kube/config"
      sudo chown "$SUDO_USER:$SUDO_USER" "$_user_home/.kube/config"
      sudo chmod 600 "$_user_home/.kube/config"
    fi
  fi

  sed -i '/source <(kubectl completion bash)/d' $HOME/.bashrc
  echo 'source <(kubectl completion bash)' >>$HOME/.bashrc
  source $HOME/.bashrc
fi
