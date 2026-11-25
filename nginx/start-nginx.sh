#!/usr/bin/env bash
. utils.sh

. haproxy/stop-haproxy.sh
. envoy/stop-envoy.sh

prnt "Starting nginx on $loadbalancer"
if ! is_address_local $loadbalancer; then
  remote_cmd $loadbalancer "sudo systemctl daemon-reload"
  remote_cmd $loadbalancer "sudo systemctl enable nginx"
  remote_cmd $loadbalancer "sudo systemctl restart nginx"
  if ! remote_cmd $loadbalancer "sudo systemctl is-active --quiet nginx"; then
    err "Failed to start nginx on $loadbalancer"
    return 1
  fi
else
  sudo systemctl daemon-reload
  sudo systemctl enable nginx
  sudo systemctl restart nginx
  if ! sudo systemctl is-active --quiet nginx; then
    err "Failed to start nginx on $loadbalancer"
    return 1
  fi
fi
prnt "Started nginx on $loadbalancer"
