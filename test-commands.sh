#!/usr/bin/env bash
#Commands for testing the cluster setup

echo -e "\e[1;42mChecking cluster nodes\e[0m"
kubectl get nodes -o wide
sleep 5
kubectl get nodes -o wide
sleep 5
kubectl get nodes -o wide

echo -e "\e[1;42mDeploying nginx pod\e[0m"
kubectl apply -f https://github.com/ratulb/k8s-remote-install/blob/main/nginx-pod.yaml

sleep 10

echo -e "\e[1;42mInstalling weave cni pluggin\e[0m"
kubectl get pod
sleep 5
kubectl get pod
sleep 5
kubectl get pod



