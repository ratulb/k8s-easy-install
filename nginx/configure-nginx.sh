#!/usr/bin/env bash

. utils.sh

rm -f /tmp/backends.txt
echo "" >/tmp/backends.txt
for _master in $masters; do
  echo "server $_master:6443;" >>/tmp/backends.txt
done
backends=$(cat /tmp/backends.txt)
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
if [[ "$this_host_ip" = "$loadbalancer" ]] || [[ "$this_host_name" = "$loadbalancer" ]]; then
  mv nginx.draft /etc/nginx/nginx.conf
else
  remote_copy nginx.draft $loadbalancer:/etc/nginx/nginx.conf
fi

prnt "Configured haproxy @$loadbalancer"
