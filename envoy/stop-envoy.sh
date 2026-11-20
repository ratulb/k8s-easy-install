#!/usr/bin/env bash
. utils.sh

prnt "Stopping envoy on $loadbalancer"
if ! is_address_local $loadbalancer; then
  remote_cmd $loadbalancer "sudo systemctl stop envoy" &>/dev/null
  remote_cmd $loadbalancer "sudo systemctl disable envoy" &>/dev/null
  remote_cmd $loadbalancer "sudo systemctl daemon-reload"
else
  sudo systemctl stop envoy &>/dev/null
  sudo systemctl disable envoy &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped envoy on $loadbalancer"
