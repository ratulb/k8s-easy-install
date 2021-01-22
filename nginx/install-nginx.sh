#!/usr/bin/env bash
. utils.sh
prnt "Installing kube-apiserver nginx load balancer on $loadbalancer"
if [[ "$this_host_ip" = "$loadbalancer" ]] || [[ "$this_host_name" = "$loadbalancer" ]]; then
  sudo command -v nginx &>/dev/null
  if [ "$?" -ne 0 ]; then
    sudo apt purge -y nginx-full nginx-common
    sudo apt autoremove -y
    sudo apt update
    sudo apt install -y nginx
    sudo apt autoremove -y
    prnt "nginx has been installed on $loadbalancer"
  else
    prnt "nginx is already installed"
  fi
else
  remote_cmd $loadbalancer command -v nginx &>/dev/null
  if [ "$?" -ne 0 ]; then
    remote_cmd $loadbalancer apt purge -y nginx-full nginx-common
    remote_cmd $loadbalancer apt autoremove -y
    remote_cmd $loadbalancer apt update
    remote_cmd $loadbalancer apt install -y nginx
    remote_cmd $loadbalancer apt autoremove -y
    prnt "nginx has been installed on $loadbalancer"
  else
    prnt "nginx is already installed"
  fi
fi
