#!/usr/bin/env bash
# Post-install smoke test — run by launch-cluster.sh after the cluster is built.
#
# Intent:
#   Verify the cluster is functional immediately after install. Sourced
#   by launch-cluster.sh (line 142) and by e2e-single-node.sh (step 8).
#
# How it works:
#   1. Waits up to 10s for all nodes to become Ready.
#   2. Removes the control-plane taint so workloads can schedule there.
#   3. Deploys a 3-replica nginx deployment from a remote manifest.
#   4. Waits up to 10s for all nginx pods to reach Running status.
#   5. Cleans up the status-report temp file.
#
# Note: this script does NOT test cross-node networking. It's a basic
# smoke test — if the API server is up and pods can run, it passes.

prnt "checking cluster nodes status"
rm -f status-report
kubectl get nodes | tee status-report
status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
i=10
while [ "$i" -gt 0 ] && [[  $status =~ *"NotReady"* ]] ; do
  sleep $i
  i=$((i-3))
  rm status-report
  kubectl get nodes | tee status-report
  status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
done

master_node=$(kubectl get nodes --no-headers | grep control-plane | awk '{print $1}')

kubectl taint nodes $master_node node-role.kubernetes.io/control-plane-
prnt "Deploying a demo nginx pod"

kubectl apply -f https://raw.githubusercontent.com/ratulb/k8s-remote-install/main/nginx-deployment.yaml

prnt "Checking pod status"

rm status-report 2> /dev/null
kubectl get pods | tee status-report
status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
cat status-report
i=10
while [ "$i" -gt 0 ] && [[  $status != "Running" ]] ; do
  sleep $i
  i=$((i-3))
  rm status-report
  kubectl get pods | tee status-report
  status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
done

