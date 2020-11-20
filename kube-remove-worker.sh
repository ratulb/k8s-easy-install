#!/usr/bin/env bash
sudo systemctl stop kubelet
kubeadm reset -y
sudo apt purge -y kubeadm kubelet kubernetes-cni kube*
