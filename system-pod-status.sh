#!/usr/bin/env bash
. utils.sh
_kubectl=$(command -v kubectl 2>/dev/null)
if [ -n "$_kubectl" ] && [ -x "$_kubectl" ]; then
  prnt "Checking kube-system pods..."
  rm -f status-report
  $_kubectl -n kube-system get pod 2>&1 | tee status-report || {
    err "kubectl failed — cluster may not be running"
    return 1
  }
  status=$(awk '{if(NR>1)print}' status-report | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
  i=$1
  secs=$2
  while [[ "$i" -gt 0 && "$status" != "Running" ]]; do
    sleep $secs
    i=$((i-1))
    rm -f status-report
    $_kubectl -n kube-system get pod 2>&1 | tee status-report || break
    status=$(awk '{if(NR>1)print}' status-report | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
  done
  rm -f status-report
else
  err "kubectl not found — has the cluster been set up?"
fi
