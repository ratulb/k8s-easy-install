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
# Use VXLAN backend (no BGP) — BGP (TCP 179) is problematic across NATed public IPs
sed -i 's/calico_backend: "bird"/calico_backend: "vxlan"/' /tmp/calico.yaml
# Remove BIRD probes (BIRD is not used in VXLAN mode)
sed -i '/- -bird-live/d; /- -bird-ready/d' /tmp/calico.yaml
kubectl apply -f /tmp/calico.yaml
# Use the Kubernetes node's InternalIP (public IP) for Calico node identity
kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=kubernetes-internal-ip 2>/dev/null || true
kubectl delete pod -n kube-system -l k8s-app=calico-node --ignore-not-found=true 2>/dev/null || true
rm -f /tmp/calico.yaml
