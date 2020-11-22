#!/usr/bin/env bash
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d
sudo rm -rf ~/.kube/
sudo iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
sudo apt purge -y kubectl
sudo apt autoremove -y
