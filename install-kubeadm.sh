#!/usr/bin/env bash
sudo apt update

# Load kernel modules required by Kubernetes
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl params required by Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Remove Docker if present (Kubernetes uses containerd directly)
if command -v docker &>/dev/null; then
  echo "Docker detected — removing in favour of containerd for Kubernetes"
  sudo apt purge -y docker-ce docker-ce-cli docker-buildx-plugin docker-ce-rootless-extras docker-compose-plugin 2>/dev/null || true
fi

# Install containerd (CRI runtime)
if ! command -v containerd &>/dev/null; then
  sudo apt install -y containerd
fi

# Configure containerd for CRI
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add the new Kubernetes apt repository (pkgs.k8s.io)
sudo apt install -y apt-transport-https ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Pin pkgs.k8s.io so kubelet/kubeadm/kubectl come from the right repo
cat <<'EOF' | sudo tee /etc/apt/preferences.d/kubernetes.pref > /dev/null
Package: kubelet kubeadm kubectl
Pin: origin pkgs.k8s.io
Pin-Priority: 1001
EOF

sudo apt update
sudo apt install -y --allow-downgrades kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet

echo "Kubeadm install has completed (Kubernetes v1.36)"
