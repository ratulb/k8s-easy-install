#!/usr/bin/env bash 
. utils.sh 

tail -2 kubeadm-init.log | tee join-cluster.cmd
sed -i "1s/^/sudo /" join-cluster.cmd
sed -i "1s/^/sleep ${sleep_time} \n/" join-cluster.cmd
chmod +x join-cluster.cmd
