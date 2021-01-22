#!/usr/bin/env bash
. utils.sh

prnt "Installing kubemaster load balancer on $loadbalancer"

if [ "$this_host_ip" = "$loadbalancer" ]; then
  . envoy/install-envoy.script
else
  remote_script $loadbalancer envoy/install-envoy.script
fi

prnt "Installed envoy on $loadbalancer"
