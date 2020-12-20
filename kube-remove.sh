#!/usr/bin/env bash
sudo kubeadm reset --cri-socket=/run/containerd/containerd.sock --force
rm -rf /var/lib/etcd
sudo rm -rf /etc/cni/net.d
sudo rm -rf ~/.kube/
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
sudo apt purge -y kubeadm kubelet kubectl
sudo apt autoremove -y
sudo ps -ef | grep kube-apiserver | grep -v grep | awk '{print $2}' | xargs kill -9 &> /dev/null
