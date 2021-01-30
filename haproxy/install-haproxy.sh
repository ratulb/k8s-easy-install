#!/usr/bin/env bash
. utils.sh
prnt "Installing kubemaster load balancer on $loadbalancer"
if [[ "$this_host_ip" = "$loadbalancer" ]] || [[ "$this_host_name" = "$loadbalancer" ]]; then
  sudo apt update
  sudo apt install -y haproxy
  sudo apt autoremove -y
else
  remote_cmd $loadbalancer apt update
  remote_cmd $loadbalancer apt install -y haproxy
  remote_cmd $loadbalancer apt autoremove -y
fi
