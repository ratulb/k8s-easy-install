#!/usr/bin/env bash
. utils.sh

for _master in $masters; do
  if is_address_local $_master; then
    sudo systemctl status kubelet --no-pager 2>&1 || true
  else
    remote_cmd $_master systemctl status kubelet --no-pager 2>&1 || true
  fi
done
