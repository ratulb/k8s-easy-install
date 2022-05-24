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
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  err "\nAborted cluster setup\n"
  return 1
fi
echo ""

cp kubeadm-init.sh kubeadm-init.sh.tmp
sed -i "s/#masters#/'$masters'/g" kubeadm-init.sh.tmp
sed -i "s/#lb_port#/$lb_port/g" kubeadm-init.sh.tmp
sed -i "s/#pod_network_cidr#/$pod_network_cidr/g" kubeadm-init.sh.tmp
sed -i "s/#loadbalancer#/$loadbalancer/g" kubeadm-init.sh.tmp
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
    prnt "Installing docker kubeadm kubelet kubectl on master(this machine $_master)"
#    . install-docker.sh
    . kube-remove.sh
    . install-kubeadm.sh
    if [ "$count" -eq 0 ]; then
      . kubeadm-init.sh.tmp
      . prepare-cluster-join.sh
      . install-cni-pluggin.sh
    else
      . master-join-cluster.cmd
    fi
  else
    prnt "Installing docker kubeadm kubelet kubectl on remote master($_master)"
 #   remote_script $_master install-docker.sh
    remote_script $_master kube-remove.sh
    remote_script $_master install-kubeadm.sh
    if [ "$count" -eq 0 ]; then
      remote_script $_master kubeadm-init.sh.tmp
      . copy-init-log.sh $_master
      . prepare-cluster-join.sh
      prnt "Installing weave cni pluggin"
      remote_script $_master install-cni-pluggin.sh
    else
      remote_script $_master master-join-cluster.cmd
    fi
    if [ "$count" -eq 0 ]; then
      . copy-kube-config.sh 'from' $_master
    else
      . copy-kube-config.sh 'to' $_master
    fi
  fi
  ((count++))
done

#workers' installtion
for worker in $workers; do
  if [ "$worker" = "$this_host_name" ] || [ "$worker" = "$this_host_ip" ]; then
    prnt "Installing kubeadm kubelet kubectl on worker $worker"
  #  . install-docker.sh
    . kube-remove.sh
    . install-kubeadm.sh
    prnt "$worker joining the cluster"
    . worker-join-cluster.cmd
  else
    prnt "Installing kubeadm kubelet kubectl on worker $worker"
   # remote_script $worker install-docker.sh
    remote_script $worker kube-remove.sh
    remote_script $worker install-kubeadm.sh
    prnt "$worker joining the cluster"
    remote_script $worker worker-join-cluster.cmd
  fi
done
. init-self.sh
. test-commands.sh
. clean-trash.sh
