#!/usr/bin/env bash
. utils.sh

tail -2 kubeadm-init.log | tee worker-join-cluster.cmd
sed -i "1s/^/sudo /" worker-join-cluster.cmd
sed -i "1s/^/sleep ${sleep_time} \n/" worker-join-cluster.cmd
chmod +x worker-join-cluster.cmd
if [ ! -z "$masters" ]; then
  cp worker-join-cluster.cmd master-join-cluster.cmd
  sed -i '/discovery-token-ca-cert-hash /s/$/ \\/' master-join-cluster.cmd
  echo "    --control-plane" >>master-join-cluster.cmd
fi
