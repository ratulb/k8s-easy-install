#!/usr/bin/env bash
#Commands for testing the cluster setup

echo -e "\e[1;42mChecking cluster nodes status\e[0m"
kubectl get nodes
sleep 10
kubectl get nodes
sleep 5
kubectl get nodes

echo -e "\e[1;42mDeploying a demo nginx pod\e[0m"
kubectl apply -f https://raw.githubusercontent.com/ratulb/k8s-remote-install/main/nginx-pod.yaml

echo -e "\e[1;42mChecking pod status\e[0m"
sleep 15
kubectl get pod
sleep 10
kubectl get pod
sleep 5
kubectl get pod

#Setup bash completion
sed -i '/source <(kubectl completion bash)/d'  ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
