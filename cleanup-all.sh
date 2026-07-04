#!/usr/bin/env bash
echo -e "\e[92m=== Full system cleanup ===\e[0m"

cd "$(dirname "$0")"

. utils.sh

# ----- Load balancer cleanup -----
cleanup_lb_local() {
  local lb=$1
  if ! command -v "$lb" &>/dev/null && [ ! -d "/etc/$lb" ]; then
    return
  fi
  echo "Removing $lb..."
  sudo systemctl stop "$lb" 2>/dev/null || true
  sudo systemctl disable "$lb" 2>/dev/null || true
  sudo apt purge -y "$lb" 2>/dev/null || true
  sudo rm -rf "/etc/$lb"
  case $lb in
    nginx)
      sudo rm -f /etc/apt/sources.list.d/nginx.list
      sudo rm -f /etc/apt/keyrings/nginx-archive-keyring.gpg
      ;;
    envoy)
      sudo rm -f /etc/apt/sources.list.d/envoy.list
      sudo rm -f /etc/apt/keyrings/envoy-keyring.gpg
      sudo rm -f /etc/systemd/system/envoy.service
      sudo systemctl daemon-reload
      ;;
  esac
}

if [ -n "${lb_type:-}" ] && [ -n "${loadbalancer:-}" ]; then
  echo "Cleaning up load balancer ($lb_type) on $loadbalancer..."
  if is_address_local "$loadbalancer"; then
    cleanup_lb_local "$lb_type"
  else
    remote_cmd "$loadbalancer" sudo systemctl stop "$lb_type" 2>/dev/null || true
    remote_cmd "$loadbalancer" sudo systemctl disable "$lb_type" 2>/dev/null || true
    remote_cmd "$loadbalancer" sudo apt purge -y "$lb_type" 2>/dev/null || true
    case $lb_type in
      nginx)
        remote_cmd "$loadbalancer" sudo rm -f /etc/apt/sources.list.d/nginx.list
        remote_cmd "$loadbalancer" sudo rm -f /etc/apt/keyrings/nginx-archive-keyring.gpg
        ;;
      envoy)
        remote_cmd "$loadbalancer" sudo rm -f /etc/apt/sources.list.d/envoy.list
        remote_cmd "$loadbalancer" sudo rm -f /etc/apt/keyrings/envoy-keyring.gpg
        remote_cmd "$loadbalancer" sudo rm -f /etc/systemd/system/envoy.service
        remote_cmd "$loadbalancer" sudo systemctl daemon-reload
        ;;
    esac
    remote_cmd "$loadbalancer" sudo rm -rf "/etc/$lb_type"
  fi
else
  for lb in haproxy nginx envoy; do
    cleanup_lb_local "$lb"
  done
fi

# ----- Kubernetes cleanup -----
echo "Cleaning up Kubernetes..."
. kube-remove.sh

# ----- Remote Kubernetes cleanup -----
for _node in $masters $workers; do
  if is_address_local "$_node"; then
    continue
  fi
  echo "Cleaning up Kubernetes on $_node..."
  remote_script "$_node" kube-remove.sh
done

# ----- Temp files -----
. clean-trash.sh

# ----- Refresh apt -----
sudo apt update 2>/dev/null || true

echo ""
echo -e "\e[92m=== Full cleanup complete ===\e[0m"
