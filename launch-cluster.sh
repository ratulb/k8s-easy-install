#!/usr/bin/env bash
. utils.sh

print_msg "Master and worker configurations:"

if [ ! -z "$loadbalancer" ]; then
  print_msg "Load balancer: $loadbalancer"
fi

if [ ! -z "$master" ]; then
  print_msg "Master: $master"
fi
if [ ! -z "$masters" ]; then
  print_msg "Masters: $masters"
fi
if [ ! -z "$workers" ]; then
  print_msg "Workers: $workers"
fi

print_msg "For remote hosts - make sure $this_host_ip's  SSH public key has been copied to them before proceeding!"

read -p "Proceed with installation(y)? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  print_msg "\nAborted cluster setup\n"
  return 1
fi

echo ""

if [ ! -z "$master" ]; then
  print_msg "Checking access to $master"
  if ! can_access_ip $master; then
    err "Can not access $master"
    exit 1
  fi
fi

if [ ! -z "$masters" ]; then
  for _mstr in $masters; do
    if ! can_access_ip $_mstr; then
      err "Can not access master ip $_mstr"
      exit 1
    fi
  done
fi

if [ ! -z "$workers" ]; then
  for wokr in $workers; do
    if ! can_access_ip $wokr; then
      err "Can not access worker $wokr"
      exit 1
    fi
  done
fi
cp kubeadm-init.sh kubeadm-init.sh.tmp
sed -i "s/#masters#/'$masters'/g" kubeadm-init.sh.tmp
sed -i "s/#lb_port#/$lb_port/g" kubeadm-init.sh.tmp
sed -i "s/#pod_network_cidr#/$pod_network_cidr/g" kubeadm-init.sh.tmp
sed -i "s/#loadbalancer#/$loadbalancer/g" kubeadm-init.sh.tmp
unset copy_kube_conf_from
echo ""
if [ -z "$masters" ]; then
  copy_kube_conf_from=$master
  if [ "$master" = "$this_host_name" ] || [ "$master" = "$this_host_ip" ]; then
    print_msg "Installing cri containerd cni on master(this computer $master)"
    . install-cri-containerd-cni.sh
    print_msg "Installing kubeadm kubelet kubectl on master(this machine $master)"
    . kube-remove.sh
    . install-kubeadm.sh
    . kubeadm-init.sh.tmp
    . configure-cgroup-driver.sh
  else
    print_msg "Installing cri containerd cni on remote master($master)"
    . execute-script-remote.sh $master install-cri-containerd-cni.sh
    print_msg "Installing kubeadm kubelet kubectl on remote master($master)"
    . execute-script-remote.sh $master kube-remove.sh
    . execute-script-remote.sh $master install-kubeadm.sh
    . execute-script-remote.sh $master kubeadm-init.sh.tmp
    . execute-script-remote.sh $master configure-cgroup-driver.sh
    . copy-init-log.sh $master
  fi
  . prepare-cluster-join.sh
else
  . haproxy/install-haproxy.sh
  . haproxy/configure-haproxy.sh
  . haproxy/start-haproxy.sh
  count=0
  #Masters' installation
  copy_kube_conf_from=$(echo $masters | cut -d ' ' -f1)
  for _master in $masters; do
    if [ "$_master" = "$this_host_name" ] || [ "$_master" = "$this_host_ip" ]; then
      print_msg "Installing cri containerd cni on master(this computer $_master)"
      . install-cri-containerd-cni.sh
      print_msg "Installing kubeadm kubelet kubectl on master(this machine $_master)"
      . kube-remove.sh
      . install-kubeadm.sh
      if [ "$count" -eq 0 ]; then
        . kubeadm-init.sh.tmp
      else
        . master-join-cluster.cmd
      fi
      . configure-cgroup-driver.sh
    else
      print_msg "Installing cri containerd cni on remote master($_master)"
      . execute-script-remote.sh $_master install-cri-containerd-cni.sh
      print_msg "Installing kubeadm kubelet kubectl on remote master($_master)"
      . execute-script-remote.sh $_master kube-remove.sh
      . execute-script-remote.sh $_master install-kubeadm.sh
      if [ "$count" -eq 0 ]; then
        . execute-script-remote.sh $_master kubeadm-init.sh.tmp
        . copy-init-log.sh $_master
      else 
	 cat master-join-cluster.cmd
        . execute-script-remote.sh $_master master-join-cluster.cmd
      fi
      . execute-script-remote.sh $_master configure-cgroup-driver.sh
    fi
    if [ "$count" -eq 0 ]; then
      . prepare-cluster-join.sh
    fi
    ((count++))
  done
fi
#Worker installation
first_master=$(echo $masters | cut -d ' ' -f1)
for worker in $workers; do
  if [ "$worker" = "$this_host_name" ] || [ "$worker" = "$this_host_ip" ]; then
    print_msg "Installing containerd on $worker"
    . install-cri-containerd-cni.sh
    print_msg "Installing kubeadm kubelet on $worker"
    . kube-remove.sh
    . install-kubeadm.sh
    print_msg "$worker joining the cluster"
    . worker-join-cluster.cmd
    . configure-cgroup-driver.sh
    . copy-kube-config.sh $copy_kube_conf_from
  else
    print_msg "Installing containerd on $worker"
    . execute-script-remote.sh $worker install-cri-containerd-cni.sh
    print_msg "Installing kubeadm kubelet on $worker"
    . execute-script-remote.sh $worker kube-remove.sh
    . execute-script-remote.sh $worker install-kubeadm.sh
    print_msg "$worker joining the cluster"
    . execute-script-remote.sh $worker worker-join-cluster.cmd
    . execute-script-remote.sh $worker configure-cgroup-driver.sh
  fi
done

. init-self.sh
#Install cni-pluggin
print_msg "Installing weave cni pluggin"
. install-cni-pluggin.sh
. test-commands.sh
