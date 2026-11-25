#!/usr/bin/env bash
. utils.sh

prnt "Installing kubemaster load balancer on $loadbalancer"

if is_address_local $loadbalancer; then
  . envoy/install-envoy.script || return 1
else
  remote_script $loadbalancer envoy/install-envoy.script || return 1
fi

prnt "Installed envoy on $loadbalancer"
