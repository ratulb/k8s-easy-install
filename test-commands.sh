#!/usr/bin/env bash
#Commands for testing the cluster setup

print_msg "Checking cluster nodes"
kubectl get nodes -o wide
sleep 10
kubectl get nodes -o wide
sleep 5
kubectl get nodes -o wide

print_msg "Deploying nginx pod"
kubectl apply -f https://raw.githubusercontent.com/ratulb/k8s-remote-install/main/nginx-pod.yaml

sleep 15
kubectl get pod
sleep 10
kubectl get pod
sleep 5
kubectl get pod



