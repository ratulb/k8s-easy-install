#!/usr/bin/env bash
. utils.sh

prnt "Stopping haproxy on $loadbalancer"
if ! is_address_local $loadbalancer; then
  remote_cmd $loadbalancer systemctl stop haproxy &>/dev/null
  remote_cmd $loadbalancer systemctl disable haproxy &>/dev/null
  remote_cmd $loadbalancer systemctl daemon-reload
else
  sudo systemctl stop haproxy &>/dev/null
  sudo systemctl disable haproxy &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped haproxy on $loadbalancer"
