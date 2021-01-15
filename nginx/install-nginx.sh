#!/usr/bin/env bash
. utils.sh
print_msg "Installing kube-apiserver nginx load balancer on $loadbalancer"
if [ "$this_host_ip" = "$loadbalancer" ]; then
  sudo command -v nginx &>/dev/null
  if [ "$?" -ne 0 ]; then
    sudo apt purge nginx-full nginx-common
    sudo apt autoremove -y
    sudo apt update
    sudo apt install -y nginx
    sudo apt autoremove -y
    print_msg "nginx has been installed on $loadbalancer"
  else
    print_msg "nginx is already installed"
  fi
else
  . execute-command-remote.sh $loadbalancer command -v nginx &>/dev/null
  if [ "$?" -ne 0 ]; then
    . execute-command-remote.sh $loadbalancer apt purge nginx-full nginx-common
    . execute-command-remote.sh $loadbalancer apt autoremove -y
    . execute-command-remote.sh $loadbalancer apt update
    . execute-command-remote.sh $loadbalancer apt install -y nginx
    . execute-command-remote.sh $loadbalancer apt autoremove -y
    print_msg "nginx has been installed on $loadbalancer"
  else
    print_msg "nginx is already installed"
  fi
fi
