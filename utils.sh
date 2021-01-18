#!/usr/bin/env bash
export usr=$(whoami)
read_setup() {
  master=
  workers=
  masters=
  while IFS="=" read -r key value; do
    case "$key" in
      "master") export master="$value" ;;
      "masters") export masters="$value" ;;
      "loadbalancer") export loadbalancer="$value" ;;
      "workers") export workers="$value" ;;
      "lb_port") export lb_port="$value" ;;
      "lb_type") export lb_type="$value" ;;
      "pod_network_cidr") export pod_network_cidr="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "cri_containerd_cni_ver") export CONTAINERD_VER="$value" ;;
      "wait_interval_post_join_cmd") export wait_interval_post_join_cmd="$value" ;;
      "#"*) ;;

    esac
  done <"setup.conf"

  sed -i "s|#CONTAINERD_VER#|$CONTAINERD_VER|g" install-cri-containerd-cni.sh
  export this_host_ip=$(echo $(hostname -i) | cut -d' ' -f1)
  export this_host_name=$(hostname)
}

"read_setup"

prnt() {
  echo -e "\e[1;32m$1\e[0m"
}

err() {
  echo -e "\e[31m$1\e[0m"
}
debug() {
  if [ ! -z "$debug" ]; then
    echo -e "\e[46m$1\e[0m"
  fi
}

warn() {
  echo -e "\e[33m$1\e[0m"

}
#Whatever is the default sleep_time
sleep_few_secs() {
  prnt "Waiting few secs..."
  sleep $sleep_time
}

is_ip() {
  local address=$1
  local rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
  if [[ "$address" =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
    debug "$address is valid ip"
    return 0
  else
    debug "$address is not valid ip"
    return 1
  fi
}
can_access_ip() {
  if is_address_local "$1"; then
    return 0
  else
    . execute-command-remote.sh $1 ls -la &>/dev/null
  fi
}

is_port_valid() {
  port_nmbr=$1
  if [[ "$port_nmbr" =~ ^[1-9][0-9]*$ ]] && [[ "$port_nmbr" -ge 80 ]] && [[ "$port_nmbr" -le 10000 ]]; then
    debug "Valid port number: $port_nmbr"
    return 0
  else
    debug "Not a valid port number: $port_nmbr"
    return 1
  fi
}

is_address_local() {
  local addr=$1
  if [[ "$addr" = $this_host_ip ]] || [[ "$addr" = "$this_host_name" ]] || [[ "$addr" = "127.0.0.1" ]] || [[ "$addr" = "localhost" ]]; then
    return 0
  else
    return 1
  fi
}

lb_address_valid() {
  local _address_=$1
  if [ -z "$_address_" ]; then
    err "Invalid address. Address should be in address:port format"
    return 1
  fi
  if ! [[ $_address_ == *":"* ]]; then
    err "Invalid address. Address should be in address:port format"
    return 1
  fi

  addr_part=$(echo $_address_ | cut -d':' -f1)
  if ! is_ip "$addr_part" && ! is_host_name_ok "$addr_part"; then
    err "Invalid address. Address should be in address:port format"
    return 1
  fi
  port_part=$(echo $_address_ | cut -d':' -f2)
  if ! is_port_valid "$port_part"; then
    err "Port not valid - should be in the 80 to 10000 range - both inclusive"
    return 1
  fi
}

is_host_name_ok() {
  local rx="^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$"
  [[ $1 =~ $rx ]] && debug "hostname is ok" || return 1
}
validate_single_master_configuration() {
  local _mstr_ip=$1
  local _workrs_=$2
  local worker_ips=''
  local m_ip=''
  if is_address_local $_mstr_ip; then
    m_ip=$(hostname -i)
  else
    m_ip=$(quiet=yes . execute-command-remote.sh $_mstr_ip hostname -i)
  fi

  debug "_mstr_ip $_mstr_ip, _workrs_ $_workrs_ and m_ip $m_ip"
  if [ ! -z "$_workrs_" ]; then
    for _w in $_workrs_; do
      if is_address_local $_w; then
        worker_ips+="$(hostname -i) "
      else
        worker_ips+="$(quiet=yes . execute-command-remote.sh $_w hostname -i) "
      fi
    done
    worker_ips=$(echo $worker_ips | xargs)
    debug "worker_ips: $worker_ips"
    for w_ip in $worker_ips; do
      if [ "$m_ip" = "$w_ip" ]; then
        err "Master ip $_mstr_ip($m_ip) collides with worker ip $w_ip"
        return 1
      fi
    done
  fi
}

validate_multi-master-configuration() {
  local _lb_addr=$1
  local _lb_port=$2
  local _mstrs_=$3
  local _workrs_=$4
  worker_ips=''
  if [ ! -z "$_workrs_" ]; then
    for _w in $_workrs_; do
      if is_address_local $_w; then
        worker_ips+="$(hostname -i) "
      else
        worker_ips+="$(quiet=yes . execute-command-remote.sh $_w hostname -i) "
      fi
    done
  fi
  worker_ips=$(echo $worker_ips | xargs)
  master_ips=''

  for _m in $_mstrs_; do
    if is_address_local $_m; then
      master_ips+="$(hostname -i) "
    else
      master_ips+="$(quiet=yes . execute-command-remote.sh $_m hostname -i) "
    fi
  done
  master_ips=$(echo $master_ips | xargs)
  lb_ip=''
  if is_address_local $_lb_addr; then
    lb_ip=$(hostname -i)
  else
    lb_ip=$(quiet=yes . execute-command-remote.sh $_lb_addr hostname -i)
  fi

  if [ ! -z "$worker_ips" ]; then
    for w_ip in $worker_ips; do
      for m_ip in $master_ips; do
        if [ "$w_ip" = "$m_ip" ]; then
          err "Master ip $m_ip is same as worker ip $w_ip"
          return 1
        fi
      done
    done
  fi
  m_and_w_ips="$master_ips $worker_ips"
  m_and_w_ips=$(echo $m_and_w_ips | xargs)
  for _ip in $m_and_w_ips; do
    if [[ "$_ip" = "$_lb_addr" ]] && [[ "$_lb_port" -eq 6443 ]]; then
      err "Loadbalancer address collides with ip $_ip yet loadbalancer port is 6443"
      return 1
    fi
  done

}

configure_single_master_setup() {
  local _master_=$1
  local _workers_=$2
  if [ -z "$_master_" ]; then
    err "Master is empty"
    return 1
  else
    sed -i "s/master=.*/master=$_master_/g" setup.conf
  fi
  if [ ! -z "$_workers_" ]; then
    sed -i "s/workers=.*/workers=$_workers_/g" setup.conf
  else
    sed -i "s/workers=.*/workers=/g" setup.conf
  fi
  sed -i "s/masters=.*/masters=/g" setup.conf
  sed -i "s/loadbalancer=.*/loadbalancer=/g" setup.conf
}

configure_multi_master_setup() {
  local _lb_addr_=$1
  local _lb_port_=$2
  local _lb_type_=$3
  local _masters_=$4
  local _workers_=$5

  if [ -z "$_lb_addr_" ]; then
    err "Loadbalancer address is not valid"
    return 1
  fi
  if [ -z "$_lb_port_" ]; then
    err "Loadbalancer port is not valid"
    return 1
  fi

  if [ -z "$_lb_type_" ]; then
    err "Loadbalancer type is not valid"
    return 1
  fi
  if [ -z "$_masters_" ]; then
    err "Master nodes entries are not valid"
    return 1
  fi
  if [ -z "$_workers_" ]; then
    warn "Workers nodes are empty!"
  fi

  sed -i "s/masters=.*/masters=$_masters_/g" setup.conf
  if [ ! -z "$_workers_" ]; then
    sed -i "s/workers=.*/workers=$_workers_/g" setup.conf
  else
    sed -i "s/workers=.*/workers=/g" setup.conf
  fi
  sed -i "s/master=.*/master=/g" setup.conf
  sed -i "s/loadbalancer=.*/loadbalancer=$_lb_addr_/g" setup.conf
  sed -i "s/lb_port=.*/lb_port=$_lb_port_/g" setup.conf
  sed -i "s/lb_type=.*/lb_type=$_lb_type_/g" setup.conf
}

#Launch busybox container called debug
k8_debug() {
  prnt "Setting up busybox debug container"
  kubectl run -i --tty --rm debug --image=busybox:1.28 --restart=Never -- sh
}

function install_etcdctl() {
  ETCD_VER="3.4.14"
  ETCD_VER=${1:-$ETCD_VER}
  DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
  prnt "Downloading etcd $ETCD_VER from $DOWNLOAD_URL"
  wget -q --timestamping ${DOWNLOAD_URL}/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz -O /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
  rm -rf /tmp/etcd-download-loc
  mkdir /tmp/etcd-download-loc
  tar xzf /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-loc --strip-components=1
  mv /tmp/etcd-download-loc/etcdctl /usr/local/bin
  which etcdctl
  etcdctl version
}
