#!/usr/bin/env bash
#If this host is not part of the cluster
. utils.sh
if [ -z "$debug" ]; then
  if [[ "$master" = "$this_host_ip" ]] || [[ "$workers" = *"$this_host_ip"* ]] || [[ "$masters" = *"$this_host_ip"* ]]; then
    return 0
  fi
fi
curl -sLO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
mkdir -p ~/.kube/

if [ ! -z "$master" ]; then
  sudo -u $usr scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master:~/.kube/config ~/.kube/
else
  first_master=$(echo $masters | cut -d ' ' -f1)
  sudo -u $usr scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $first_master:~/.kube/config ~/.kube/
fi
chown $(id -u):$(id -g) ~/.kube/config

sed -i '/source <(kubectl completion bash)/d' ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
