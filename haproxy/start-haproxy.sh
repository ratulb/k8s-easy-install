#!/usr/bin/env bash
. utils.sh

. nginx/stop-nginx.sh
. envoy/stop-envoy.sh
prnt "Starting haproxy on $loadbalancer"
if ! is_address_local $loadbalancer; then
  remote_cmd $loadbalancer "sudo sed -i '/net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf"
  remote_cmd $loadbalancer "echo 'net.ipv4.ip_nonlocal_bind=1' | sudo tee -a /etc/sysctl.conf > /dev/null"
  remote_cmd $loadbalancer "sudo sysctl -p"
  remote_cmd $loadbalancer "sudo systemctl daemon-reload"
  remote_cmd $loadbalancer "sudo systemctl enable haproxy"
  remote_cmd $loadbalancer "sudo systemctl restart haproxy"
else
  sudo sed -i '/net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
  echo 'net.ipv4.ip_nonlocal_bind=1' | sudo tee -a /etc/sysctl.conf > /dev/null
  sudo sysctl -p
  sudo systemctl daemon-reload
  sudo systemctl enable haproxy
  sudo systemctl restart haproxy
fi
prnt "Started haproxy on $loadbalancer"
