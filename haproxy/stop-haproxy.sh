#!/usr/bin/env bash
. utils.sh

prnt "Stopping haproxy on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer systemctl stop haproxy &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl disable haproxy &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
else
  sudo systemctl stop haproxy &>/dev/null
  sudo systemctl disable haproxy &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped haproxy on $loadbalancer"
