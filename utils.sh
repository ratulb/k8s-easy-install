#!/usr/bin/env bash
export usr=$(whoami)
read_setup() {
  master=
  workers=
  while IFS="=" read -r key value; do
    case "$key" in
      "master") export master="$value" ;;
      "masters") export masters="$value" ;;
      "loadbalancer") export loadbalancer="$value" ;;
      "workers") export workers="$value" ;;
      "lb_port") export lb_port="$value" ;;
      "pod_network_cidr") export pod_network_cidr="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "cri_containerd_cni_ver") export CONTAINERD_VER="$value" ;;
      "#"*) ;;

    esac
  done <"setup.conf"

  sed -i "s|#CONTAINERD_VER#|$CONTAINERD_VER|g" install-cri-containerd-cni.sh
  export this_host_ip=$(echo $(hostname -i) | cut -d' ' -f1)
  export this_host_name=$(hostname)
}

"read_setup"

print_msg() {
  echo -e "\e[1;32m$1\e[0m"
}

err() {
  echo -e "\e[31m$1\e[0m"
}

#Whatever is the default sleep_time
sleep_few_secs() {
  print_msg "Waiting few secs..."
  sleep $sleep_time
}

#Launch busybox container called debug
k8_debug() {
  print_msg "Setting up busybox debug container"
  kubectl run -i --tty --rm debug --image=busybox:1.28 --restart=Never -- sh
}
can_access_ip() {
  if [ "$1" = "$this_host_ip" ]; then
    return 0
  else
    . execute-command-remote.sh $1 ls -la &>/dev/null
  fi
}

function install_etcdctl() {
  ETCD_VER="3.4.14"
  ETCD_VER=${1:-$ETCD_VER}
  DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
  print_msg "Downloading etcd $ETCD_VER from $DOWNLOAD_URL"
  wget -q --timestamping ${DOWNLOAD_URL}/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz -O /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
  rm -rf /tmp/etcd-download-loc
  mkdir /tmp/etcd-download-loc
  tar xzf /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-loc --strip-components=1
  mv /tmp/etcd-download-loc/etcdctl /usr/local/bin
  which etcdctl
  etcdctl version

}
