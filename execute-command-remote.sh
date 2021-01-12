#!/usr/bin/env bash 
. utils.sh
remote_host=$1
shift
args="$@"
print_msg "Executing command on $remote_host"
sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $remote_host $args
