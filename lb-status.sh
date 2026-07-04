#!/usr/bin/env bash
. utils.sh

if [ -z "$loadbalancer" ] || [ -z "$lb_type" ]; then
  err "Load balancer not configured"
  return 1
fi

if is_address_local $loadbalancer; then
  sudo systemctl status $lb_type --no-pager 2>&1 || true
else
  remote_cmd $loadbalancer systemctl status $lb_type --no-pager 2>&1 || true
fi
