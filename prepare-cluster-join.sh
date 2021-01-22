#!/usr/bin/env bash
. utils.sh
tail -2 kubeadm-init.log | tee worker-join-cluster.cmd
sed -i "1s/^/sudo /" worker-join-cluster.cmd
sed -i "1s/^/sleep ${sleep_time} \n/" worker-join-cluster.cmd
chmod +x worker-join-cluster.cmd
if [ ! -z "$loadbalancer" ]; then
  rm -f master-join-cluster.cmd
  echo "echo 'master-join-run' > /tmp/master-join.run" >>master-join-cluster.cmd
  echo '' >>master-join-cluster.cmd
  cat worker-join-cluster.cmd >>master-join-cluster.cmd
  sed -i '/discovery-token-ca-cert-hash /s/$/\\/' master-join-cluster.cmd
  cat kubeadm-init.log | grep '\--control-plane' >>master-join-cluster.cmd
  sed -i '/control-plane /s/$/ \\/' master-join-cluster.cmd
  echo '    --cri-socket /run/containerd/containerd.sock \'
  #echo '    --ignore-preflight-errors=all -v=6' >>master-join-cluster.cmd
  echo '    --ignore-preflight-errors=all -v=6 | tee /tmp/master-join-response' >>master-join-cluster.cmd
  echo '' >>master-join-cluster.cmd
  echo 'rm -f /tmp/master-join.run' >>master-join-cluster.cmd
  echo 'return 0' >>master-join-cluster.cmd
  chmod +x master-join-cluster.cmd
  cnt=0
  for me in $masters; do
    if [[ $cnt -eq 0 ]] || [[ "$me" = "$this_host_ip" ]] || [[ "$me" = "$this_host_name" ]]; then
      :
    else
      copy_remote master-join-cluster.cmd $me:~/
    fi
    ((cnt++))
  done
fi
