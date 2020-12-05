#!/usr/bin/env bash
#Commands for testing the cluster setup

echo -e "\e[1;42mChecking cluster nodes status\e[0m"
rm status-report
kubectl get nodes | tee status-report
status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $2}' | tr "\n" " ")
i=15
while [ "$i" -gt 0 ] && [[ $status =~ "NotReady" ]] ; do
  sleep $i
  i=$((i-5))
  rm status-report
  kubectl get nodes | tee status-report
  status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $2}' | tr "\n" " ")
done
kubectl taint nodes --all node-role.kubernetes.io/master-
echo -e "\e[1;42mDeploying a demo nginx pod\e[0m"
kubectl apply -f https://raw.githubusercontent.com/ratulb/k8s-remote-install/main/nginx-deployment.yaml

echo -e "\e[1;42mChecking pod status\e[0m"

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

#Setup bash completion
sed -i '/source <(kubectl completion bash)/d'  ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
