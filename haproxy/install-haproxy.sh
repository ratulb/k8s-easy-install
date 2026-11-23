#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
. utils.sh
prnt "Installing kubemaster load balancer on $loadbalancer"
if is_address_local $loadbalancer; then
  sudo DEBIAN_FRONTEND=noninteractive apt update
  sudo DEBIAN_FRONTEND=noninteractive apt install -y haproxy
  sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y
else
  remote_cmd $loadbalancer sudo DEBIAN_FRONTEND=noninteractive apt update
  remote_cmd $loadbalancer sudo DEBIAN_FRONTEND=noninteractive apt install -y haproxy
  remote_cmd $loadbalancer sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y
fi
