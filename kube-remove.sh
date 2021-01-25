#!/usr/bin/env bash
echo -e "\e[92mRemoving kubernetes on $(hostname)($(hostname -i))\e[0m"

sudo rm -f /etc/kubernetes/manifests/* 
if command -v crictl &>/dev/null; then
  pod_ids=$(crictl pods | awk '{if(NR>1)print}' | awk '{print $1}' | tr "\n" " ")
  if [ ! -z "$pod_ids" ]; then
    sudo crictl stopp $pod_ids && sudo crictl rmp $pod_ids -a
  fi
fi
sudo kubeadm reset --force || sudo kubeadm reset --force --cri-socket=/run/containerd/containerd.sock
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
sudo ps -ef | grep kube-apiserver | grep -v grep | awk '{print $2}' | xargs kill -9 &>/dev/null
sudo systemctl daemon-reload

echo -e "\e[92mRemoved kubernetes on $(hostname)($(hostname -i))\e[0m"
