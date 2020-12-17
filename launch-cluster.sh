#!/usr/bin/env bash 
. utils.sh

print_msg "Configurations read from setup.conf"
print_msg "Master: $master"
print_msg "Workers: $workers"
print_msg "Please make sure $HOME/.ssh/id_rsa.pub SSH public key has been copied \
to remote machines!"

read -p "Proceed with installation? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    print_msg "\nAborted cluster setup\n"
    exit 1
fi

echo "\n"
host=$(hostname)
host_ip=$(hostname -i)
print_msg "This host is : $host"
print_msg "This host ip is : $host_ip"
#Master installation
if [ "$master" = "$host" ] || [ "$master" = "$host_ip" ]
then 
  print_msg "Installing docker on master(this computer $master)"
  . install-docker.sh
  print_msg "Installing kubeadm kubelet kubectl on master(this machine $master)"
  . kube-remove.sh
  . install-kubeadm.sh
  . kubeadm-init.sh
else 
  print_msg "Installing docker on remote master($master)"
  . execute-file-remote.sh $master install-docker.sh
  print_msg "Installing kubeadm kubelet kubectl on remote master($master)"
  . execute-file-remote.sh $master kube-remove.sh
  . execute-file-remote.sh $master install-kubeadm.sh
  . execute-file-remote.sh $master kubeadm-init.sh
  . copy-init-log.sh $master
fi
. prepare-cluster-join.sh
#Worker installation
for worker in $workers; do 
  if [ "$worker" = "$host" ] || [ "$worker" = "$host_ip" ]
then 
  print_msg "Installing docker on $worker"
  . install-docker.sh
  print_msg "Installing kubeadm kubelet on $worker"
  . kube-remove.sh
  . install-kubeadm.sh
  print_msg "$worker joining the cluster"
  . join-cluster.cmd
  . copy-kube-config.sh $master
else 
  print_msg "Installing docker on $worker"
  . execute-file-remote.sh $worker install-docker.sh
  print_msg "Installing kubeadm kubelet on $worker"
  . execute-file-remote.sh $worker kube-remove.sh
  . execute-file-remote.sh $worker install-kubeadm-worker.sh
  print_msg "$worker joining the cluster"
  . execute-file-remote.sh $worker join-cluster.cmd
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
