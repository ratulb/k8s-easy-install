#!/usr/bin/env bash
# Install Calico CNI (replaces Weave, which has been archived upstream)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml
