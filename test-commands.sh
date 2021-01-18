#!/usr/bin/env bash
. utils.sh
#Commands for testing the cluster setup

prnt "checking cluster nodes status"
rm -f status-report
kubectl get nodes | tee status-report
status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
i=15
while [ "$i" -gt 0 ] && [[ ! $status = "NotReady" ]] ; do
  sleep $i
  i=$((i-5))
  rm status-report
  kubectl get nodes | tee status-report
  status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
done

master_node=$(kubectl get nodes --no-headers | grep 'control-plane,master' | awk '{print $1}')

kubectl taint nodes $master_node node-role.kubernetes.io/master-
prnt "Deploying a demo nginx pod"

kubectl apply -f https://raw.githubusercontent.com/ratulb/k8s-remote-install/main/nginx-deployment.yaml

prnt "Checking pod status"

rm status-report 2> /dev/null
kubectl get pods | tee status-report
status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | tr "\n" " ")

i=15
while [ "$i" -gt 0 ] && [[ ! $status =~ "Running Running Running" ]] ; do
  sleep $i
  i=$((i-5))
  rm status-report
  kubectl get pods | tee status-report
  status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | tr "\n" " ")
done

