#!/usr/bin/env bash 
tail -2 kubeadm-init.log | tee join-cluster.cmd
chmod +x join-cluster.cmd
