#!/usr/bin/env bash
# End-to-end single-node test.
#
# Intent:
#   Validate the full install pipeline on a single node (controller
#   and workload on the same machine). Covers all three load balancer
#   types. This is the simplest/fastest test for basic regression.
#
# How it works:
#   1. Writes a single-node setup.conf (masters=localhost, no workers).
#   2. Sources each install script step-by-step in order:
#      LB install/configure/start -> kube-remove -> install-kubeadm ->
#      kubeadm-init -> prepare-cluster-join -> install-cni-pluggin ->
#      init-self -> test-commands -> clean-trash.
#   3. Each step runs via `bash -c ". script.sh"` to isolate sourced
#      scripts and prevent exit-code leaks between steps.
#   4. On failure the step function prints the error and exits.
#   5. Prints node status and pods on success.
#   6. The lb_type argument selects which LB to test (default: envoy).
#   7. Does NOT tear down — the cluster is left running for inspection.
#
# Usage: bash tests/e2e-single-node.sh [lb_type]
#   lb_type: envoy (default), nginx, haproxy
# Must be run from project root; user must have passwordless sudo.

set +e
cd "$(dirname "$0")/.."
ROOT=$PWD

lb_type="${1:-envoy}"

cat > setup.conf <<CONF
workers=
masters=localhost
pod_network_cidr=192.168.0.0/16
loadbalancer=localhost
lb_type=$lb_type
lb_port=6643
sleep_time=3
cri_containerd_cni_ver=1.3.4
CONF

. utils.sh

cp kubeadm-init.sh kubeadm-init.sh.tmp
sed -i "s/#masters#/'$masters'/g" kubeadm-init.sh.tmp
sed -i "s/#lb_port#/$lb_port/g" kubeadm-init.sh.tmp
sed -i "s|#pod_network_cidr#|$pod_network_cidr|g" kubeadm-init.sh.tmp
sed -i "s/#loadbalancer#/$loadbalancer/g" kubeadm-init.sh.tmp

echo ""
echo "=== Single-node cluster install (LB: $lb_type) ==="
echo "  masters:      $masters"
echo "  loadbalancer: $loadbalancer:$lb_port ($lb_type)"
echo ""

step() {
  local n=$1 desc=$2; shift 2
  echo "--- Step $n: $desc ---"
  "$@"
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "!! Step $n FAILED (exit $rc) !!" >&2
    return $rc
  fi
}

step 1 "$lb_type LB" bash -c ". $lb_type/install-$lb_type.sh && . $lb_type/configure-$lb_type.sh && . $lb_type/start-$lb_type.sh"
step 2 "Remove existing k8s" bash -c ". kube-remove.sh"
step 3 "Install kubelet/kubeadm/kubectl" bash -c ". install-kubeadm.sh"
step 4 "kubeadm init" bash -c ". kubeadm-init.sh.tmp"
step 5 "Extract join commands" bash -c ". prepare-cluster-join.sh"
step 6 "Install Calico CNI" bash -c ". install-cni-pluggin.sh"
step 7 "init-self (kubectl + kubeconfig)" bash -c ". init-self.sh"
step 8 "test-commands" bash -c ". test-commands.sh"
step 9 "clean-trash" bash -c ". clean-trash.sh"

echo ""
echo "=== Install complete ==="
echo "--- Node status ---"
kubectl get nodes -o wide
echo "--- Pods ---"
kubectl get pods -A
