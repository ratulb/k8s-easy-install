#!/usr/bin/env bash

. utils.sh

backends=""
for _master in $masters; do
  _backend_host=$_master
  if [[ "$_master" == "$loadbalancer" ]] || { is_address_local "$_master" && is_address_local "$loadbalancer"; }; then
    _backend_host=127.0.0.1
  fi
  backends="${backends}    server $_backend_host:6443;
"
done
cat <<EOF | tee /tmp/nginx.config.snippet
stream {
  upstream kube-apiservers {
    $backends
  }
  server {
    listen $lb_port;
    proxy_pass kube-apiservers;
  }
}
EOF

cp nginx/nginx.conf nginx.draft
cat /tmp/nginx.config.snippet >> nginx.draft
if is_address_local $loadbalancer; then
  sudo cp nginx.draft /etc/nginx/nginx.conf
  rm -f nginx.draft
else
  remote_copy nginx.draft $loadbalancer:/tmp/nginx.conf.draft
  remote_cmd $loadbalancer "sudo mkdir -p /etc/nginx"
  remote_cmd $loadbalancer "sudo cp /tmp/nginx.conf.draft /etc/nginx/nginx.conf"
  remote_cmd $loadbalancer "rm -f /tmp/nginx.conf.draft"
fi

prnt "Configured nginx on $loadbalancer"
