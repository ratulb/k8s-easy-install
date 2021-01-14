#!/usr/bin/env bash
. utils.sh

tail -2 kubeadm-init.log | tee worker-join-cluster.cmd
sed -i "1s/^/sudo /" worker-join-cluster.cmd
sed -i "1s/^/sleep ${sleep_time} \n/" worker-join-cluster.cmd
chmod +x worker-join-cluster.cmd
if [ ! -z "$masters" ]; then
  cp worker-join-cluster.cmd master-join-cluster.cmd
  sed -i '/discovery-token-ca-cert-hash /s/$/\\/' master-join-cluster.cmd
  cat kubeadm-init.log | grep '\--control-plane' >> master-join-cluster.cmd
  sed -i '/control-plane /s/$/ \\/' master-join-cluster.cmd
  echo '    --cri-socket /run/containerd/containerd.sock' >> master-join-cluster.cmd
fi
