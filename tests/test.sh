#!/usr/bin/env bash
# Stress/regression test: repeat installs with random load balancers.
#
# Intent:
#   Catch flaky failures by running the full install pipeline many
#   times with a random LB type each iteration. Tests that the
#   install is idempotent and survives repeated destroy-rebuild cycles.
#
# How it works:
#   1. Sets up setup.conf for multi-node (unless overridden).
#   2. Picks a random LB type (haproxy/envoy/nginx with weighted distribution).
#   3. Runs launch-cluster.sh with echo 'y' to auto-confirm.
#   4. Dumps kubectl get nodes to test-result.txt after each install.
#   5. Sleeps 30s between iterations to let the previous cluster settle
#      before the next install tears it down and rebuilds.
#   6. Repeats for the given count (default 20).
#
# Usage: bash tests/test.sh [count]
#   count: number of iterations (default 20). Output in tests/test-result.txt.
# Must be run from project root; user must have passwordless sudo.

. utils.sh

num=$(echo $((1 + $RANDOM % 10)))
_lb=''
run_count=20
if [ ! -z "$1" ]; then
  run_count=$1
fi

count=0
while [[ $count -lt $run_count ]]; do
  if [ $num -lt 3 ]; then
    _lb=haproxy
  elif [[ $num -ge 3 ]] && [[ $num -le 6 ]]; then
    _lb=envoy
  else
    _lb=nginx
  fi
  sed -i "s/lb_type=.*/lb_type=$_lb/" setup.conf
  prnt "lb is: $_lb"
  echo "lb is: $_lb" >>tests/test-result.txt

  echo 'y' | . launch-cluster.sh

  kubectl get nodes >>tests/test-result.txt
  sleep 30
  ((count++))
  num=$(echo $((1 + $RANDOM % 10)))
done
