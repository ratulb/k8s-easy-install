#!/usr/bin/env bash

. utils.sh

num_masters=1
backends=""
for _master in $masters; do
  _backend_host=$_master
  if [[ "$_master" == "$loadbalancer" ]] || { is_address_local "$_master" && is_address_local "$loadbalancer"; }; then
    _backend_host=127.0.0.1
  fi
  backends="${backends}  server master-$num_masters $_backend_host:6443 check fall 3 rise 2
"
  ((num_masters++))
done

cp haproxy/haproxy.cfg haproxy.draft
cat <<EOF >> haproxy.draft

frontend kube-apiservers
    bind 0.0.0.0:$lb_port
    option tcplog
    option tcp-check
    mode tcp
    default_backend kube-apiserver-nodes

backend kube-apiserver-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    $backends
EOF
if is_address_local $loadbalancer; then
  sudo cp haproxy.draft /etc/haproxy/haproxy.cfg
  rm -f haproxy.draft
else
  remote_copy haproxy.draft $loadbalancer:/etc/haproxy/haproxy.cfg
fi

prnt "Configured haproxy on $loadbalancer"
