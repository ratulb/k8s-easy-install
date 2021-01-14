#!/usr/bin/env bash 

sudo apt update
command -v wget &> /dev/null
[ $? -eq 0 ] || sudo apt install -y wget 

echo -e "\e[1;32mInstalling cri-containerd-cni.\e[0m"

sudo systemctl stop containerd
sudo systemctl disable containerd
sudo rm -rf /etc/systemd/system/containerd.service 
sudo systemctl daemon-reload

sudo apt install libseccomp2

rm -rf $HOME/containerd_download/
mkdir $HOME/containerd_download/

wget -q https://storage.googleapis.com/cri-containerd-release/cri-containerd-cni-1.3.4.linux-amd64.tar.gz -O $HOME/containerd_download/cri-containerd-cni-1.3.4.linux-amd64.tar.gz
#sudo tar --no-overwrite-dir -C / -xzf $HOME/containerd_download/cri-containerd-cni-1.3.4.linux-amd64.tar.gz
sudo tar -C / -xzf $HOME/containerd_download/cri-containerd-cni-1.3.4.linux-amd64.tar.gz

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo echo "KUBELET_EXTRA_ARGS=--cgroup-driver=systemd" > /etc/default/kubelet

sudo mkdir -p  /etc/systemd/system/kubelet.service.d/
#cat << EOF | sudo tee  /etc/systemd/system/kubelet.service.d/0-containerd.conf
#[Service]                                                 
#Environment="KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
#EOF

sudo mkdir -p /etc/containerd
sudo cp config.toml /etc/containerd/

# Apply sysctl params without reboot
sudo systemctl daemon-reload
sudo sysctl --system
sudo systemctl start containerd
sudo systemctl enable containerd
sudo systemctl restart kubelet

sleep 3
pod_ids=$(crictl pods | awk '{if(NR>1)print}' | awk '{print $1}' | tr "\n" " ")
if [ ! -z "$pod_ids" ]; then
  crictl stopp $pod_ids && crictl rmp $pod_ids
fi

echo -e "\e[1;32mInstalled cri-containerd-cni.\e[0m"

