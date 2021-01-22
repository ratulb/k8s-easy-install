#!/usr/bin/env bash
. utils.sh

prnt "Stopping envoy on $loadbalancer"
if [[ "$this_host_ip" != "$loadbalancer" ]] && [[ "$this_host_name" != "$loadbalancer" ]]; then
  remote_cmd $loadbalancer systemctl stop envoy &>/dev/null
  remote_cmd $loadbalancer systemctl disable envoy &>/dev/null
  remote_cmd $loadbalancer systemctl daemon-reload
else
  sudo systemctl stop envoy &>/dev/null
  sudo systemctl disable envoy &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped envoy on $loadbalancer"
