#!/usr/bin/env bash
# Install Calico CNI (replaces Weave, which has been archived upstream)
#
# We download the manifest and switch from IPIP to VXLAN mode because IPIP
# (protocol 4) is often blocked in cloud environments (GCP, etc.). VXLAN
# runs over UDP (port 4789) and works in all major clouds.
CALICO_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml"

curl -sSL "$CALICO_MANIFEST_URL" -o /tmp/calico.yaml
sed -i '/CALICO_IPV4POOL_IPIP/{n;s/value: "Always"/value: "Never"/}' /tmp/calico.yaml
sed -i '/CALICO_IPV4POOL_VXLAN/{n;s/value: "Never"/value: "Always"/}' /tmp/calico.yaml
kubectl apply -f /tmp/calico.yaml
rm -f /tmp/calico.yaml
