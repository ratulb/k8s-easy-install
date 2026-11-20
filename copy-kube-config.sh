#!/usr/bin/env bash
. utils.sh

# Resolve the home of the invoking (non-root) user so kubeconfig lands
# where kubectl is actually run from, even when this script runs under sudo.
if [ -n "${SUDO_USER:-}" ]; then
  controller_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  controller_home="$HOME"
fi
[ -z "$controller_home" ] && controller_home="$HOME"
mkdir -p "$controller_home/.kube"

case $1 in
  from)
    remote_copy $2:~/.kube/config "$controller_home/.kube/config"
    chown "$usr:$usr" "$controller_home/.kube/config" 2>/dev/null || true
    sed -i '/source <(kubectl completion bash)/d' "$controller_home/.bashrc" 2>/dev/null || true
    echo 'source <(kubectl completion bash)' >>"$controller_home/.bashrc" 2>/dev/null || true
    ;;
  to)
    remote_copy "$controller_home/.kube/config" $2:~/.kube/config.tmp
    remote_cmd $2 'mkdir -p $HOME/.kube'
    remote_cmd $2 'cp /tmp/kubeconfig.tmp $HOME/.kube/config'
    remote_cmd $2 'chown $(id -u):$(id -g) $HOME/.kube/config'
    remote_cmd $2 'rm -f /tmp/kubeconfig.tmp'
    remote_cmd $2 "sed -i '/source <(kubectl completion bash)/d' ~/.bashrc"
    remote_cmd $2 "echo 'source <(kubectl completion bash)' >> ~/.bashrc"
    ;;
  *) ;;
esac
