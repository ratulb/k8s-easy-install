#!/usr/bin/env bash 

sudo sed -i "17icgroupDriver: systemd" /var/lib/kubelet/config.yaml

sudo systemctl restart kubelet
