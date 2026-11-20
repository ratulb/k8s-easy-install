#!/usr/bin/env bash
. utils.sh

if [ -n "${SUDO_USER:-}" ]; then
  controller_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  controller_home="$HOME"
fi
[ -z "$controller_home" ] && controller_home="$HOME"
mkdir -p "$controller_home/.kube"

cluster_members="$masters $workers"
cluster_members=$(echo $cluster_members | xargs)

if ! [[ "$cluster_members" = *"$this_host_name"* ]] && ! [[ "$cluster_members" = *"$this_host_ip"* ]] && ! [[ "$cluster_members" = *"$this_host_public_ip"* ]]; then
  curl -sLO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

local_master=false
for _m in $masters; do
  if is_address_local $_m; then
    local_master=true
    break
  fi
done

if $local_master; then
  sudo cp /etc/kubernetes/admin.conf "$controller_home/.kube/config"
else
  master_1=$(echo $masters | cut -d' ' -f1)
  remote_copy $master_1:~/.kube/config "$controller_home/.kube/config"
fi

chown "$usr:$usr" "$controller_home/.kube/config" 2>/dev/null || true
chmod 600 "$controller_home/.kube/config" 2>/dev/null || true
sed -i '/source <(kubectl completion bash)/d' "$controller_home/.bashrc" 2>/dev/null || true
echo 'source <(kubectl completion bash)' >>"$controller_home/.bashrc" 2>/dev/null || true
