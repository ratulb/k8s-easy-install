#!/usr/bin/env bash
. utils.sh

prnt "Stopping nginx on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer systemctl stop nginx &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl disable nginx &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
else
  sudo systemctl stop nginx &>/dev/null
  sudo systemctl disable nginx &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped nginx on $loadbalancer"
