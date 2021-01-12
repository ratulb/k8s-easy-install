#!/usr/bin/env bash
. utils.sh
print_msg "Installing kubemaster load balancer on $loadbalancer"
if [ "$this_host_ip" = "$loadbalancer" ]; then
  . sudo apt update
  . sudo apt install -y haproxy
  . sudo apt autoremove -y
else
  . execute-command-remote.sh $loadbalancer apt update
  . execute-command-remote.sh $loadbalancer apt install -y haproxy
  . execute-command-remote.sh $loadbalancer apt autoremove -y
fi
