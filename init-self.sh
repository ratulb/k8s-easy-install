#!/usr/bin/env bash
. utils.sh

cluster_members="$masters $workers"
cluster_members=$(echo $cluster_members | xargs)

if ! [[ "$cluster_members" = *"$this_host_name"* ]] && ! [[ "$cluster_members" = *"$this_host_ip"* ]]; then
  curl -sLO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

if [[ "$masters" =~ "$this_host_name" ]] || [[ "$masters" =~ "$this_host_ip" ]]; then
  sudo cp /etc/kubernetes/admin.conf ~/.kube/config
else
  master_1=$(echo $masters | cut -d' ' -f1)
  mkdir -p $HOME/.kube/
  remote_copy $master_1:$HOME/.kube/config $HOME/.kube/config
fi

chown $(id -u):$(id -g) ~/.kube/config
sed -i '/source <(kubectl completion bash)/d' ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
