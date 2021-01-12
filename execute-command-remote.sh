#!/usr/bin/env bash 
. utils.sh
print_msg "Executing command on $remote_host"
remote_host=$1
shift
args="$@"
sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $remote_host $args
