#!/usr/bin/env bash
echo -e "\e[92mRemoving kubernetes on $(hostname)($(hostname -i))\e[0m"

sudo kubeadm reset --force
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/cni
sudo rm -rf ~/.kube/
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /etc/systemd/system/kubelet.service.d/
IPTABLES=$(command -v iptables || command -v /usr/sbin/iptables || echo "")
if [ -n "$IPTABLES" ]; then
  sudo "$IPTABLES" -F && sudo "$IPTABLES" -t nat -F && sudo "$IPTABLES" -t mangle -F && sudo "$IPTABLES" -X
fi
sudo apt purge -y --allow-change-held-packages kubeadm kubelet kubectl
sudo rm -f /usr/local/bin/kubectl

# Remove Kubernetes apt repo, keyring, and pin
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo rm -f /etc/apt/preferences.d/kubernetes.pref

# Remove k8s sysctl and modules-load configs
sudo rm -f /etc/sysctl.d/k8s.conf
sudo rm -f /etc/modules-load.d/k8s.conf

sudo apt autoremove -y
sudo rm -rf /opt/cni/bin

# Reset containerd for a clean state
sudo systemctl stop containerd
sudo rm -rf /var/lib/containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl start containerd

api_svc=$(sudo ss -lptn 'sport = :6443' | cut -d'"' -f2)
api_id=$(sudo ss -lptn 'sport = :6443' | grep pid | cut -d'=' -f2 | cut -d',' -f1)
sudo systemctl stop $api_svc &>/dev/null
sudo kill -9 $api_id &>/dev/null

etcd_lstr=$(sudo ss -lptn 'sport = :2379' | cut -d'"' -f2)
lstr_id=$(sudo ss -lptn 'sport = :2379' | grep pid | cut -d'=' -f2 | cut -d',' -f1)
sudo systemctl stop $etcd_lstr &>/dev/null
sudo kill -9 $lstr_id &>/dev/null

etcd_peer=$(sudo ss -lptn 'sport = :2380' | cut -d'"' -f2)
peer_id=$(sudo ss -lptn 'sport = :2380' | grep pid | cut -d'=' -f2 | cut -d',' -f1)
sudo systemctl stop $etcd_peer &>/dev/null
sudo kill -9 $peer_id &>/dev/null
sudo systemctl daemon-reload

for svc in kube-scheduler kube-controller-manager kube-proxy kube-apiserver; do
  _pid=$(pgrep -f "$svc" 2>/dev/null)
  if [ ! -z "$_pid" ]; then
    echo "Terminating orphan process $svc"
    sudo kill -9 $_pid
  fi
done

sudo systemctl daemon-reload

echo -e "\e[92mRemoved kubernetes on $(hostname)($(hostname -i))\e[0m"
