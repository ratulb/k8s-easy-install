#!/usr/bin/env bash
. utils.sh
remote_host=$1
if [ -z "$quiet" ]; then
  prnt "Executing command on $remote_host"
fi
shift
args="$@"
sudo -u $usr ssh -o "StrictHostKeyChecking=no" -o "ConnectTimeout=3" $remote_host $args
