#!/usr/bin/env bash 
#Execute remote command
. utils.sh
print_msg "Hostname followed by file containing commands"
sudo -u $usr ssh -o "StrictHostKeyChecking no" $1 < $2
