#!/usr/bin/env bash
. utils.sh

print_msg "Starting nginx on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer systemctl stop haproxy &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl disable haproxy &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
  . execute-command-remote.sh $loadbalancer systemctl stop nginx
  . execute-command-remote.sh $loadbalancer systemctl enable nginx
  . execute-command-remote.sh $loadbalancer systemctl start nginx
else
  sudo systemctl stop haproxy &>/dev/null
  sudo systemctl disable haproxy &>/dev/null
  sudo systemctl daemon-reload
  sudo systemctl stop nginx
  sudo systemctl enable nginx
  sudo systemctl start nginx
fi
