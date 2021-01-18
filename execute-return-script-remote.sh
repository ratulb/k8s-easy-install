#!/usr/bin/env bash 
#Execute remote command
. utils.sh
prnt "Executing a return on $1"
sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $2 $1:~/ 
sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $1 ". $2"
#sudo -u $usr ssh -q -o "LogLevel=ERROR" -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $1 < $2 &> /dev/null

