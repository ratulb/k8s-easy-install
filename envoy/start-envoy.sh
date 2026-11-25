#!/usr/bin/env bash
. utils.sh

. nginx/stop-nginx.sh
. haproxy/stop-haproxy.sh

prnt "Starting envoy on $loadbalancer"

if ! is_address_local $loadbalancer; then
  remote_cmd $loadbalancer "sudo systemctl daemon-reload"
  remote_cmd $loadbalancer "sudo systemctl enable envoy"
  remote_cmd $loadbalancer "sudo systemctl restart envoy"
  if ! remote_cmd $loadbalancer "sudo systemctl is-active --quiet envoy"; then
    err "Failed to start envoy on $loadbalancer"
    return 1
  fi
else
  sudo systemctl daemon-reload
  sudo systemctl enable envoy
  sudo systemctl restart envoy
  if ! sudo systemctl is-active --quiet envoy; then
    err "Failed to start envoy on $loadbalancer"
    return 1
  fi
fi
prnt "Started envoy on $loadbalancer"
