#!/usr/bin/env bash 
. utils.sh

read_setup setup.conf

echo -e "\e[1;42mMaster is : $master\e[0m"
echo -e "\e[1;42mWorkers are : $workers\e[0m"
host=$(hostname)
host_ip=$(hostname -i)
echo -e "\e[1;42mThis host is : $host\e[0m"
echo -e "\e[1;42mThis host ip is : $host_ip\e[0m"
#Master installation
if [ "$master" = "$host" ] || [ "$master" = "$host_ip" ]
then 
  echo -e "\e[1;42mInstalling docker on local master\e[0m"
  . install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet kubectl on local master\e[0m"
  . kube-remove-master.sh
  . install-kubeadm.sh
  . kubeadm-init.sh
else 
  echo -e "\e[1;42mInstalling docker on remote master\e[0m"
  . execute-file-remote.sh $master install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet kubectl on remote master\e[0m"
  . execute-file-remote.sh $master kube-remove-master.sh
  . execute-file-remote.sh $master install-kubeadm.sh
  . execute-file-remote.sh $master kubeadm-init.sh
fi
. prepare-cluster-join.sh
#Worker installation
for worker in $workers; do 
  if [ "$worker" = "$host" ] || [ "$worker" = "$host_ip" ]
then 
  echo -e "\e[1;42mInstalling docker on local worker\e[0m"
  . install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet on local worker\e[0m"
  . kube-remove-worker.sh
  . install-kubeadm-worker.sh
  echo -e "\e[1;42m$worker joining the cluster\e[0m"
  . join-cluster.cmd
else 
  echo -e "\e[1;42mInstalling docker on $worker\e[0m"
  . execute-file-remote.sh $worker install-docker.sh
  echo -e "\e[1;42mInstalling kubeadm kubelet on $worker\e[0m"
  . execute-file-remote.sh $worker kube-remove-worker.sh
  . execute-file-remote.sh $worker install-kubeadm-worker.sh
  echo -e "\e[1;42m$worker joining the cluster\e[0m"
  . execute-file-remote.sh $worker join-cluster.cmd
fi 

done

#Install cni-pluggin
echo -e "\e[1;42mInstalling weave cni pluggin\e[0m"
if [ "$master" = "$host" ] || [ "$master" = "$host_ip" ]
 then
   . install-cni-pluggin.sh
     sleep 10
   . test-commands.sh 
 else
   . execute-file-remote.sh $master install-cni-pluggin.sh
     sleep 10
   . execute-file-remote.sh $master test-commands.sh
fi 

	



