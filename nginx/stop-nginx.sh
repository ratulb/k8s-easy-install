#!/usr/bin/env bash
. utils.sh

prnt "Stopping nginx on $loadbalancer"
if ! is_address_local $loadbalancer; then	
  remote_cmd $loadbalancer systemctl stop nginx &>/dev/null
  remote_cmd $loadbalancer systemctl disable nginx &>/dev/null
  remote_cmd $loadbalancer systemctl daemon-reload
else
  sudo systemctl stop nginx &>/dev/null
  sudo systemctl disable nginx &>/dev/null
  sudo systemctl daemon-reload
fi
prnt "Stopped nginx on $loadbalancer"
