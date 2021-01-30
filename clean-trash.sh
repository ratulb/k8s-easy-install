#!/usr/bin/env bash 
if [ -z "$debug" ]; then
  rm -f kubeadm-init.sh.tmp
  rm -f envoy.draft
  rm -f worker-join-cluster.cmd
  rm -f master-join-cluster.cmd
  rm -f kubeadm-init.log
  rm -f status-report
  rm -f nginx.draft
  rm -f haproxy.draft
fi
rm -f 0

