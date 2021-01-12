#!/usr/bin/env bash
. utils.sh
sudo -u $usr  scp -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" $1:~/kubeadm-init.log .

