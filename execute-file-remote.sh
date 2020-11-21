#!/usr/bin/env bash 
#Execute remote command
. utils.sh
echo "Hostname followed by file containing commands"
sudo -u $usr ssh -o "StrictHostKeyChecking no" $1 < $2
