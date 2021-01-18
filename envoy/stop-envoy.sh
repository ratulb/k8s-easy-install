#!/usr/bin/env bash
. utils.sh

prnt "Stopping envoy on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer systemctl stop envoy &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl disable envoy &>/dev/null
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
else
  sudo systemctl stop envoy &>/dev/null
  sudo systemctl disable envoy &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped envoy on $loadbalancer"
