#!/usr/bin/env bash
echo -e "\e[1;32mRemoving kubernetes on $(hostname)($(hostname -i))\e[0m"
sudo kubeadm reset --force &>/dev/null
sudo kubeadm reset --force --cri-socket=/run/containerd/containerd.sock
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
sudo ps -ef | grep kube-apiserver | grep -v grep | awk '{print $2}' | xargs kill -9 &> /dev/null
sudo systemctl daemon-reload

echo -e "\e[1;32mRemoved kubernetes on $(hostname)($(hostname -i))\e[0m"
