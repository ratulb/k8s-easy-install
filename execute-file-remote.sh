#!/usr/bin/env bash 
#Execute remote command
. utils.sh
print_msg "Executing on $1"
sudo -u $usr ssh -o "StrictHostKeyChecking no" $1 < $2
