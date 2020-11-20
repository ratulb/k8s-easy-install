#!/usr/bin/env bash 
. utils.sh

read_setup setup.conf

echo -e "\e[1;42mMaster is : $master"
echo -e "\e[1;42mWorkers are : $workers"
host=$(hostname)
host_ip=$(hostname -i)
echo -e "\e[1;42mThis host is : $host"
echo -e "\e[1;42mThis host ip is : $host_ip"
is_master=false
is_worker=false
#Master installation
if [ "$master" = "$host" ] || [ "$master" = "$host_ip" ]
then 
  echo -e "\e[1;42mInstalling docker on local master"
  . install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet kubectl on local master"
  . kube-remove-master.sh
  . install-kubeadm.sh
  . kubeadm-init.sh
else 
  echo -e "\e[1;42mInstalling docker on remote master"
  . excute-file-remote.sh $master install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet kubectl on remote master"
  . execute-file-remote.sh $master kube-remove-master.sh
  . execute-file-remote.sh $master install-kubeadm.sh
  . execute-file-remote.sh $master kubeadm-init.sh
fi
. prepare-cluster-join.sh
#Worker installation
for worker in $workers; do 
  if [ "$worker" = "$host" ] || [ "$worker" = "$host_ip" ]
then 
  echo -e "\e[1;42mInstalling docker on local worker"
  . install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet on local worker"
  . kube-remove-worker.sh
  . install-kubeadm-worker.sh
  echo -e "\e[1;42m$worker joining the cluster"
  . join-cluster.cmd
else 
  echo -e "\e[1;42mInstalling docker on $worker"
  . execute-file-remote.sh $worker install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet on $worker"
  . execute-file-remote.sh $worker kube-remove-worker.sh
  . execute-file-remote.sh $worker install-kubeadm-worker.sh
  echo -e "\e[1;42m$worker joining the cluster"
  . execute-file-remote.sh $worker join-cluster.cmd
fi 

done



