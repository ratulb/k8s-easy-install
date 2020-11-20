#!/usr/bin/env bash
sudo systemctl stop kubelet
kubeadm reset -y
sudo apt purge -y kubeadm kubelet kubectl kubernetes-cni kube*
