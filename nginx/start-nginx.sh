#!/usr/bin/env bash
. utils.sh

. haproxy/stop-haproxy.sh
. envoy/stop-envoy.sh

print_msg "Starting nginx on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
  . execute-command-remote.sh $loadbalancer systemctl enable nginx
  . execute-command-remote.sh $loadbalancer systemctl restart nginx
else
  sudo systemctl daemon-reload
  sudo systemctl enable nginx
  sudo systemctl restart nginx
fi
print_msg "Started nginx on $loadbalancer"
