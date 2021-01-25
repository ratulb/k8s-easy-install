#!/usr/bin/env bash 

sudo sed -i "17icgroupDriver: systemd" /var/lib/kubelet/config.yaml
echo -e "\e[92mConfigured kubelet for systemd cgroup. Restarting kubelet on host $(hostname -i)\e[0m"

sudo systemctl restart kubelet
