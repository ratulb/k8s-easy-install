#!/usr/bin/env bash
. utils.sh

. nginx/stop-nginx.sh
. haproxy/stop-haproxy.sh

prnt "Starting envoy on $loadbalancer"

if [[ "$this_host_ip" != "$loadbalancer" ]] && [[ "$this_host_name" != "$loadbalancer" ]]; then
  remote_cmd $loadbalancer systemctl daemon-reload
  remote_cmd $loadbalancer systemctl enable envoy
  remote_cmd $loadbalancer systemctl restart envoy
else
  sudo systemctl daemon-reload
  sudo systemctl enable envoy
  sudo systemctl restart envoy
fi
prnt "Started envoy on $loadbalancer"
