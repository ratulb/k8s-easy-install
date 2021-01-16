#!/usr/bin/env bash
. utils.sh

. nginx/stop-nginx.sh
. haproxy/stop-haproxy.sh
print_msg "Starting envoy on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
  . execute-command-remote.sh $loadbalancer systemctl enable envoy
  . execute-command-remote.sh $loadbalancer systemctl restart envoy
else
  sudo systemctl daemon-reload
  sudo systemctl enable envoy
  sudo systemctl restart envoy
fi
print_msg "Started envoy on $loadbalancer"