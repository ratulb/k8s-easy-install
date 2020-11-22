#!/usr/bin/env bash 
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1:~/kubeadm-init.log .

