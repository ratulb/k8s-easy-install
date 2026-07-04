#!/usr/bin/env bash
. utils.sh

. haproxy/stop-haproxy.sh
. envoy/stop-envoy.sh

prnt "Starting nginx on $loadbalancer"
if ! is_address_local $loadbalancer; then
  remote_cmd $loadbalancer systemctl daemon-reload
  remote_cmd $loadbalancer systemctl enable nginx
  remote_cmd $loadbalancer systemctl restart nginx
else
  sudo systemctl daemon-reload
  sudo systemctl enable nginx
  sudo systemctl restart nginx
fi
prnt "Started nginx on $loadbalancer"
