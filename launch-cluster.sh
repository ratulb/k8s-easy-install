#!/usr/bin/env bash
. utils.sh
if [[ -z "$masters" ]]; then
  err "No master nodes provided"
  return 1
fi

master_count=$(echo $masters | wc -w)
if [[ "$master_count" -gt 1 ]] && ([[ -z $loadbalancer ]] || [[ -z "$lb_type" ]] || [[ -z "$lb_port" ]]); then
  err "For multi-master setup loadbalancer is needed - but configuration not correct"
  return 1
fi

if ([[ ! -z "$loadbalancer" ]] && ([[ -z "$lb_type" ]] || [[ -z "$lb_port" ]])) || ([[ ! -z "$lb_type" ]] && ([[ -z "$loadbalancer" ]] || [[ -z "$lb_port" ]])) || ([[ ! -z "$lb_port" ]] && ([[ -z "$lb_type" ]] || [[ -z "$loadbalancer" ]])); then
  err "Loadbalancer configuration is not complete"
  return 1
fi

if [ ! -z "$loadbalancer" ]; then
  prnt "Checking connectivity to loadbalancer..."
  if ! can_access_address $loadbalancer; then
    err "Loadbalancer is provided but can not access loadbalancer at $loadbalancer"
    return 1
  fi
fi

prnt "Checking connectivity to master node(s)..."
for _mstr in $masters; do
  if ! can_access_address $_mstr; then
    err "Can not access master address $_mstr"
    return 1
  fi
done

if [ ! -z "$workers" ]; then
  prnt "Checking connectivity to worker node(s)..."
  for wokr in $workers; do
    if ! can_access_address $wokr; then
      err "Can not access worker $wokr"
      return 1
    fi
  done
fi

echo ""
prnt "In-progress cluster configurations:"
if [ ! -z "$loadbalancer" ]; then
  prnt "Load balancer: $loadbalancer"
  prnt "Load balancer type: $lb_type"
  prnt "Load balancer port: $lb_port"
fi
prnt "Masters: $masters"
if [ ! -z "$workers" ]; then
  prnt "Workers: $workers"
fi

prnt "For remote hosts - make sure $this_host_name($this_host_ip)'s  SSH public key has been copied to them befo
re proceeding!"
read -p "Proceed with installation(y)? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  err "\nAborted cluster setup\n"
  return 1
fi
echo ""

cp kubeadm-init.sh kubeadm-init.sh.tmp
sed -i "s/#masters#/'$masters'/g" kubeadm-init.sh.tmp
sed -i "s/#lb_port#/$lb_port/g" kubeadm-init.sh.tmp
sed -i "s/#pod_network_cidr#/$pod_network_cidr/g" kubeadm-init.sh.tmp
sed -i "s/#loadbalancer#/$loadbalancer/g" kubeadm-init.sh.tmp
#cp master-join-monitor.cmd mjm.cmd.tmp
#sed -i "s|#wait_interval_post_join_cmd#|$wait_interval_post_join_cmd|g" mjm.cmd.tmp
if [ ! -z "$loadbalancer" ]; then
  case $lb_type in
    haproxy)
      . haproxy/install-haproxy.sh
      . haproxy/configure-haproxy.sh
      . haproxy/start-haproxy.sh
      ;;
    nginx)
      . nginx/install-nginx.sh
      . nginx/configure-nginx.sh
      . nginx/start-nginx.sh
      ;;
    envoy)
      . envoy/install-envoy.sh
      . envoy/configure-envoy.sh
      . envoy/start-envoy.sh
      ;;
    *)
      err "I am not programmed to receive you!"
      ;;
  esac
fi
count=0
#Masters' installation
for _master in $masters; do
  if [ "$_master" = "$this_host_name" ] || [ "$_master" = "$this_host_ip" ]; then
    prnt "Installing kubeadm kubelet kubectl on master(this machine $_master)"
    . kube-remove.sh
    . install-kubeadm.sh
    prnt "Installing cri containerd cni on master(this computer $_master)"
    . install-cri-containerd-cni.sh
    if [ "$count" -eq 0 ]; then
      . kubeadm-init.sh.tmp
      . prepare-cluster-join.sh
    else
      . master-join-cluster.cmd
    fi
    . configure-cgroup-driver.sh
  else
    prnt "Installing kubeadm kubelet kubectl on remote master($_master)"
    remote_script $_master kube-remove.sh
    remote_script $_master install-kubeadm.sh
    prnt "Installing cri containerd cni on remote master($_master)"
    remote_script $_master install-cri-containerd-cni.sh
    if [ "$count" -eq 0 ]; then
      remote_script $_master kubeadm-init.sh.tmp
      . copy-init-log.sh $_master
      . prepare-cluster-join.sh
      prnt "Installing weave cni pluggin"
    else
      remote_script $_master master-join-cluster.cmd
    fi
    if [ "$count" -eq 0 ]; then
      . copy-kube-config.sh 'from' $_master
    else
      . copy-kube-config.sh 'to' $_master
    fi
    . copy-config-toml.sh $_master
    remote_script $_master configure-cgroup-driver.sh
  fi
  ((count++))
done

#workers' installtion
for worker in $workers; do
  if [ "$worker" = "$this_host_name" ] || [ "$worker" = "$this_host_ip" ]; then
    prnt "Installing kubeadm kubelet kubectl on worker $worker"
    . kube-remove.sh
    . install-kubeadm.sh
    prnt "Installing cri containerd cni on worker $worker"
    . install-cri-containerd-cni.sh
    prnt "$worker joining the cluster"
    . worker-join-cluster.cmd
    . configure-cgroup-driver.sh
  else
    prnt "Installing kubeadm kubelet kubectl on worker $worker"
    remote_script $worker kube-remove.sh
    remote_script $worker install-kubeadm.sh
    prnt "Installing cri containerd cni on $worker"
    remote_script $worker install-cri-containerd-cni.sh
    prnt "$worker joining the cluster"
    remote_script $worker worker-join-cluster.cmd
    . copy-config-toml.sh $worker
    remote_script $worker configure-cgroup-driver.sh
  fi
done

. install-cni-pluggin.sh
. init-self.sh
. test-commands.sh
. clean-trash.sh
