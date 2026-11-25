#!/usr/bin/env bash
# Install Calico CNI (replaces Weave, which has been archived upstream)
#
# We download the manifest and switch from IPIP to VXLAN mode because IPIP
# (protocol 4) is often blocked in cloud environments (GCP, etc.). VXLAN
# runs over UDP (port 4789) and works in all major clouds.
CALICO_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml"

rc=0
curl -fsSL "$CALICO_MANIFEST_URL" -o /tmp/calico.yaml || rc=$?
if [ "$rc" -eq 0 ]; then
  sed -i '/CALICO_IPV4POOL_IPIP/{n;s/value: "Always"/value: "Never"/}' /tmp/calico.yaml || rc=$?
  sed -i '/CALICO_IPV4POOL_VXLAN/{n;s/value: "Never"/value: "Always"/}' /tmp/calico.yaml || rc=$?
  # Use VXLAN backend (no BGP) — BGP (TCP 179) is problematic across NATed public IPs
  sed -i 's/calico_backend: "bird"/calico_backend: "vxlan"/' /tmp/calico.yaml || rc=$?
fi
if [ "$rc" -eq 0 ]; then
  kubectl apply -f /tmp/calico.yaml || rc=$?
fi
# VXLAN mode does not use BIRD; drop bird checks so probes do not fail.
kubectl patch daemonset calico-node -n kube-system --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/exec/command","value":["/bin/calico-node","-felix-live"]},{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/exec/command","value":["/bin/calico-node","-felix-ready"]}]' 2>/dev/null || true
# Use Kubernetes node InternalIP and disable BGP/BIRD for VXLAN-only mode.
kubectl set env daemonset/calico-node -n kube-system CLUSTER_TYPE=k8s IP_AUTODETECTION_METHOD=kubernetes-internal-ip 2>/dev/null || true
kubectl delete pod -n kube-system -l k8s-app=calico-node --ignore-not-found=true 2>/dev/null || true
rm -f /tmp/calico.yaml
[ "$rc" -eq 0 ]
