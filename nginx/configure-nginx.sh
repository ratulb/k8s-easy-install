#!/usr/bin/env bash

. utils.sh

backends=""
for _master in $masters; do
  backends="${backends}    server $_master:6443;
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
  remote_copy nginx.draft $loadbalancer:/etc/nginx/nginx.conf
fi

prnt "Configured nginx on $loadbalancer"
