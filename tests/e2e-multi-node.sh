#!/usr/bin/env bash
# End-to-end multi-node test: cross-node pod networking.
#
# Intent:
#   Validate that pods on different Kubernetes nodes can communicate
#   over the cluster network (Calico VXLAN). Also validates that the
#   full build pipeline (launch-cluster.sh) and full teardown
#   (cleanup-all.sh) work correctly together.
#
# How it works:
#   1. Builds a multi-node cluster from scratch (echo y | launch-cluster.sh).
#   2. Creates nginx pods on the control-plane and worker nodes
#      (via nodeSelector) plus busybox curl pods on each node.
#   3. Verifies HTTP connectivity in both directions:
#      control-plane pod -> worker pod, worker pod -> control-plane pod.
#   4. Cleans up test pods, then tears down the entire cluster.
#   5. Repeats the build/test/teardown cycle for the given iteration count.
#
# Usage: bash tests/e2e-multi-node.sh [iterations]
#   iterations: number of build -> test -> teardown cycles (default 1)
#
# Prerequisites:
#   - setup.conf configured for multi-node (masters + workers)
#   - Passwordless sudo on local node
#   - SSH key authorized + passwordless sudo on all remote nodes

set +e
cd "$(dirname "$0")/.."
ROOT=$PWD

. utils.sh

iterations="${1:-1}"

# Verify multi-node configuration
if [ -z "$workers" ]; then
  echo "!! setup.conf must define workers for multi-node test !!" >&2
  echo "!! Current masters='$masters' workers='$workers' !!" >&2
  exit 1
fi

pass_count=0
fail_count=0

cross_node_test() {
  echo "--- Cross-node pod networking test ---"

  CONTROL_PLANE=$(kubectl get nodes --no-headers | grep control-plane | awk '{print $1}')
  WORKER=$(kubectl get nodes --no-headers | grep -v control-plane | awk '{print $1}')

  if [ -z "$CONTROL_PLANE" ] || [ -z "$WORKER" ]; then
    echo "!! Need both control-plane and worker nodes !!" >&2
    return 1
  fi
  echo "Control-plane: $CONTROL_PLANE, Worker: $WORKER"

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-master
  labels:
    app: test-master
spec:
  nodeSelector:
    kubernetes.io/hostname: $CONTROL_PLANE
  containers:
  - name: nginx
    image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: test-worker
  labels:
    app: test-worker
spec:
  nodeSelector:
    kubernetes.io/hostname: $WORKER
  containers:
  - name: nginx
    image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: test-curl
  labels:
    app: test-curl
spec:
  nodeSelector:
    kubernetes.io/hostname: $CONTROL_PLANE
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: test-curl-w
  labels:
    app: test-curl-w
spec:
  nodeSelector:
    kubernetes.io/hostname: $WORKER
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "3600"]
EOF

  for pod in test-master test-worker test-curl test-curl-w; do
    echo "  Waiting for $pod..."
    if ! kubectl wait --for=condition=Ready "pod/$pod" --timeout=120s; then
      echo "!! $pod never became Ready !!" >&2
      kubectl get pods -o wide
      return 1
    fi
  done

  MASTER_POD_IP=$(kubectl get pod test-master -o jsonpath='{.status.podIP}')
  WORKER_POD_IP=$(kubectl get pod test-worker -o jsonpath='{.status.podIP}')
  echo "Master nginx pod IP: $MASTER_POD_IP"
  echo "Worker nginx pod IP: $WORKER_POD_IP"

  if [ -z "$MASTER_POD_IP" ] || [ -z "$WORKER_POD_IP" ]; then
    echo "!! Failed to get pod IPs !!" >&2
    return 1
  fi

  failed=""

  echo "Test 1: control-plane pod -> worker pod"
  if kubectl exec test-curl -- wget -qO- "http://$WORKER_POD_IP" 2>/dev/null | grep -q "Welcome to nginx"; then
    echo "  PASS"
  else
    echo "  FAIL" >&2
    echo "  curl output:" >&2
    kubectl exec test-curl -- wget -qO- "http://$WORKER_POD_IP" 2>&1 || true
    failed=1
  fi

  echo "Test 2: worker pod -> control-plane pod"
  if kubectl exec test-curl-w -- wget -qO- "http://$MASTER_POD_IP" 2>/dev/null | grep -q "Welcome to nginx"; then
    echo "  PASS"
  else
    echo "  FAIL" >&2
    echo "  curl output:" >&2
    kubectl exec test-curl-w -- wget -qO- "http://$MASTER_POD_IP" 2>&1 || true
    failed=1
  fi

  kubectl delete pod test-master test-worker test-curl test-curl-w --now 2>/dev/null || true

  [ -z "$failed" ]
  return $?
}

for ((i=1; i<=iterations; i++)); do
  echo ""
  echo "=========================================="
  echo "  Multi-node test iteration $i/$iterations"
  echo "=========================================="
  echo ""

  # ---- Build cluster ----
  echo ">>> Building cluster..."
  echo 'y' | bash launch-cluster.sh
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "!! Cluster build FAILED (exit $rc) !!" >&2
    ((fail_count++))
    bash cleanup-all.sh 2>/dev/null || true
    continue
  fi

  # ---- Cross-node networking test ----
  if cross_node_test; then
    echo ">>> Cross-node networking: PASS"
    ((pass_count++))
  else
    echo ">>> Cross-node networking: FAIL"
    ((fail_count++))
  fi

  # ---- Teardown ----
  echo ">>> Tearing down cluster..."
  bash cleanup-all.sh
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "!! Teardown returned exit code $rc !!" >&2
  fi
done

echo ""
echo "=========================================="
echo "  Results: $pass_count passed, $fail_count failed"
echo "=========================================="

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
