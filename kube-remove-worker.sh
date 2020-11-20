#!/usr/bin/env bash
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d
sudo iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
sudo apt autoremove
