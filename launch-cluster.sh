#!/usr/bin/env bash 
. utils.sh

print_msg "Master and worker configurations:"

print_msg "Master: $master"
print_msg "Workers: $workers"

print_msg "For remote hosts - make sure $(whoami)'s  SSH public key has been copied to them before proceeding!"

read -p "Proceed with installation? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    print_msg "\nAborted cluster setup\n"
    exit 1
fi

echo ""
host=$(hostname)
host_ip=$(hostname -i)
print_msg "This host is : $host"
print_msg "This host ip is : $host_ip"
#Master installation
if [ "$master" = "$host" ] || [ "$master" = "$host_ip" ]
then 
  print_msg "Installing docker on master(this computer $master)"
  . install-containerd.sh
  print_msg "Installing kubeadm kubelet kubectl on master(this machine $master)"
  . kube-remove.sh
  . install-kubeadm.sh
  . kubeadm-init.sh
  . configure-cgroup-driver.sh
else 
  print_msg "Installing docker on remote master($master)"
  . execute-file-remote.sh $master install-containerd.sh
  print_msg "Installing kubeadm kubelet kubectl on remote master($master)"
  . execute-file-remote.sh $master kube-remove.sh
  . execute-file-remote.sh $master install-kubeadm.sh
  . execute-file-remote.sh $master kubeadm-init.sh
  . execute-file-remote.sh $master configure-cgroup-driver.sh
  . copy-init-log.sh $master
fi
. prepare-cluster-join.sh
#Worker installation
for worker in $workers; do 
  if [ "$worker" = "$host" ] || [ "$worker" = "$host_ip" ]
then 
  print_msg "Installing docker on $worker"
  . install-containerd.sh
  print_msg "Installing kubeadm kubelet on $worker"
  . kube-remove.sh
  . install-kubeadm.sh
  print_msg "$worker joining the cluster"
  . join-cluster.cmd
  . configure-cgroup-driver.sh
  . copy-kube-config.sh $master
else 
  print_msg "Installing docker on $worker"
  . execute-file-remote.sh $worker install-containerd.sh
  print_msg "Installing kubeadm kubelet on $worker"
  . execute-file-remote.sh $worker kube-remove.sh
  . execute-file-remote.sh $worker install-kubeadm-worker.sh
  print_msg "$worker joining the cluster"
  . execute-file-remote.sh $worker join-cluster.cmd
  . execute-file-remote.sh $master configure-cgroup-driver.sh
fi 
done

#Install cni-pluggin
print_msg "Installing weave cni pluggin"
if [ "$master" = "$host" ] || [ "$master" = "$host_ip" ]
 then
   . install-cni-pluggin.sh
     sleep_few_secs
   . test-commands.sh 
 else
   . execute-file-remote.sh $master install-cni-pluggin.sh
     sleep_few_secs
   . execute-file-remote.sh $master test-commands.sh
fi 
. init-self.sh
