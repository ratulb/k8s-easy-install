#!/usr/bin/env bash
set +e
cd "$(dirname "$0")/.."

LB_TYPE=nginx
LB_PORT=8080
MODE="${1:-all}"

case "$MODE" in
  single|all-masters|all) ;;
  *)
    echo "Usage: bash tests/e2e-nginx-8080.sh [single|all-masters|all]" >&2
    exit 1
    ;;
esac

. utils.sh
ORIGINAL_NODES="$masters $workers"

BACKUP=$(mktemp)
cp setup.conf "$BACKUP"
KEEP_CONFIG=0
restore_setup() {
  if [ "$KEEP_CONFIG" -eq 0 ]; then
    cp "$BACKUP" setup.conf
  fi
  rm -f "$BACKUP"
}
trap restore_setup EXIT

write_setup() {
  cat > setup.conf <<CONF
workers=$1
masters=$2
pod_network_cidr=192.168.0.0/16
loadbalancer=$3
lb_type=$LB_TYPE
lb_port=$LB_PORT
sleep_time=3
cri_containerd_cni_ver=1.3.4
CONF
  . utils.sh
}

cleanup() {
  bash cleanup-all.sh >/dev/null 2>&1 || true
}

check_lb() {
  local lb=$1
  echo "--- Checking $lb:$LB_PORT ---"
  if is_address_local "$lb"; then
    systemctl is-active --quiet nginx || { echo "!! nginx is not active locally !!" >&2; return 1; }
    grep -q "listen $LB_PORT;" /etc/nginx/nginx.conf || { echo "!! /etc/nginx/nginx.conf has no listen $LB_PORT !!" >&2; return 1; }
    sudo ss -tln 2>/dev/null | grep -q ":${LB_PORT} " || { echo "!! nothing listening on $LB_PORT !!" >&2; return 1; }
  else
    remote_cmd "$lb" "sudo systemctl is-active --quiet nginx" || { echo "!! nginx is not active on $lb !!" >&2; return 1; }
    remote_cmd "$lb" "grep -q 'listen $LB_PORT;' /etc/nginx/nginx.conf" || { echo "!! $lb has no listen $LB_PORT in nginx.conf !!" >&2; return 1; }
    remote_cmd "$lb" "sudo ss -tln 2>/dev/null | grep -q ':${LB_PORT} '" || { echo "!! nothing listening on $lb:$LB_PORT !!" >&2; return 1; }
  fi
  curl -ksS --max-time 10 "https://$lb:$LB_PORT/healthz" 2>/dev/null | grep -q ok || {
    echo "!! kube-apiserver healthz failed via $lb:$LB_PORT !!" >&2
    return 1
  }
  echo "  PASS"
}

check_nodes() {
  local expected=$1
  hash -r
  echo "--- Waiting for $expected node(s) Ready ---"
  for _ in $(seq 1 60); do
    local total ready
    total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || true)
    if [ "$total" -eq "$expected" ] && [ "$ready" -eq "$expected" ]; then
      kubectl get nodes -o wide
      echo "  PASS"
      return 0
    fi
    sleep 5
  done
  kubectl get nodes -o wide >&2
  echo "!! expected $expected Ready nodes !!" >&2
  return 1
}

run_single() {
  echo ""
  echo "=========================================="
  echo "  nginx LB $LB_PORT - single node"
  echo "=========================================="
  cleanup
  write_setup "" localhost localhost
  echo ">>> Installing..."
  echo 'y' | bash launch-cluster.sh || return 1
  check_lb localhost || return 1
  check_nodes 1 || return 1
}

run_all_masters() {
  echo ""
  echo "=========================================="
  echo "  nginx LB $LB_PORT - all nodes as masters"
  echo "=========================================="
  cleanup
  local all_nodes="$ORIGINAL_NODES"
  [ -n "$all_nodes" ] || { echo "!! setup.conf must define masters and/or workers !!" >&2; return 1; }
  local lb_node=""
  local n ordered=""
  for n in $all_nodes; do
    if ! is_address_local "$n"; then lb_node=$n; break; fi
  done
  [ -n "$lb_node" ] || lb_node=$(echo "$all_nodes" | awk '{print $1}')
  for n in $all_nodes; do
    [ "$n" = "$lb_node" ] && continue
    ordered="$ordered $n"
  done
  ordered="$lb_node$ordered"
  local count
  count=$(echo "$ordered" | wc -w)
  write_setup "" "$ordered" "$lb_node"
  echo "  masters: $ordered"
  echo "  loadbalancer: $lb_node:$LB_PORT"
  echo ">>> Installing..."
  echo 'y' | bash launch-cluster.sh || return 1
  check_lb "$lb_node" || return 1
  check_nodes "$count" || return 1
}

failed=0
case "$MODE" in
  single) run_single || failed=1 ;;
  all-masters) run_all_masters || failed=1 ;;
  all)
    run_single || failed=1
    run_all_masters || failed=1
    ;;
esac

echo ""
if [ "$failed" -eq 0 ]; then
  KEEP_CONFIG=1
  echo "RESULT: PASS ($MODE)"
else
  echo "RESULT: FAIL ($MODE)" >&2
fi
exit "$failed"
