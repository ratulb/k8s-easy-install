#!/usr/bin/env bash
. utils.sh

if [ ! -f kubeadm-init.log ]; then
  err "kubeadm-init.log not found — has kubeadm init been run?"
  return 1
fi

# Extract full join commands from kubeadm-init.log.
# Reassemble continuation lines (backslash at end -> next line).
full_join_cmds=$(awk '
  /^kubeadm join/ {
    cmd = $0
    while (cmd ~ /\\$/) {
      getline next_line
      gsub(/^[ \t]+/, "", next_line)
      cmd = substr(cmd, 1, length(cmd)-1) next_line
    }
    gsub(/\\/, "", cmd)
    gsub(/[ \t]+/, " ", cmd)
    print cmd
  }
' kubeadm-init.log)

if [ -z "$full_join_cmds" ]; then
  err "No kubeadm join commands found in kubeadm-init.log"
  return 1
fi

# Write worker join command (no --control-plane flag)
worker_cmd=$(echo "$full_join_cmds" | grep -v -- '--control-plane' | head -1)
if [ -n "$worker_cmd" ]; then
  {
    echo "sleep ${sleep_time:-3}"
    echo "sudo $worker_cmd"
  } > worker-join-cluster.cmd
  chmod +x worker-join-cluster.cmd
fi

# Write control-plane join command (has --control-plane flag)
if [ -n "$loadbalancer" ]; then
  master_cmd=$(echo "$full_join_cmds" | grep -- '--control-plane' | head -1)
  if [ -n "$master_cmd" ]; then
    {
      echo "sleep ${sleep_time:-3}"
      echo "sudo $master_cmd --ignore-preflight-errors=all -v=6 | tee /tmp/master-join-response"
    } > master-join-cluster.cmd
    chmod +x master-join-cluster.cmd
  fi
fi
