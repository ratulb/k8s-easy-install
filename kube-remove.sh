#!/usr/bin/env bash
echo -e "\e[92mRemoving kubernetes on $(hostname)($(hostname -i))\e[0m"

sudo kubeadm reset --force
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/cni/net.d
sudo rm -rf ~/.kube/
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /etc/systemd/system/kubelet.service.d/
sudo iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
sudo apt purge -y kubeadm kubelet kubectl
sudo apt autoremove -y
sudo rm -rf /opt/cni/bin

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

for svc in kube-scheduler kube-controller-manager kube-controll kube-proxy kube-apiserver; do
  _pid=$(pgrep $svc)
  if [ ! -z "$_pid" ]; then
    echo "Terminating orphan process $svc"
    sudo kill -9 $_pid
  fi
done

sudo systemctl daemon-reload

echo -e "\e[92mRemoved kubernetes on $(hostname)($(hostname -i))\e[0m"
