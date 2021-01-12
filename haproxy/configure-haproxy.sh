#!/usr/bin/env bash
. utils.sh

rm -f /tmp/backends.txt
echo "" >/tmp/backends.txt
num_masters=1
for _master in $masters; do
  echo server master-$num_masters $_master:6443 check fall 3 rise 2 >>/tmp/backends.txt
  ((num_masters++))
done
backends=$(cat /tmp/backends.txt)

cat <<EOF | tee /tmp/haproxy.config.snippet

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
cp haproxy/haproxy.cfg haproxy.draft

cat /tmp/haproxy.config.snippet >>haproxy.draft
if [[ "$this_host_ip" = "$loadbalancer" ]] || [[ "$this_host_name" = "$loadbalancer" ]]; then
  mv haproxy.draft /etc/haproxy/haproxy.cfg
else
  sudo -u $usr scp haproxy.draft $loadbalancer:/etc/haproxy/haproxy.cfg
fi

print_msg "Configured haproxy @$loadbalancer"
