#!/usr/bin/env bash
. utils.sh

. nginx/stop-nginx.sh
. envoy/stop-envoy.sh
prnt "Starting haproxy on $loadbalancer"
if [[ "$this_host_ip" != "$loadbalancer" ]] && [[ "$this_host_name" != "$loadbalancer" ]]; then
  remote_cmd $loadbalancer sed -i '/net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
  remote_cmd $loadbalancer echo 'net.ipv4.ip_nonlocal_bind=1' >>/etc/sysctl.conf
  remote_cmd $loadbalancer sysctl -p
  remote_cmd $loadbalancer systemctl daemon-reload
  remote_cmd $loadbalancer systemctl enable haproxy
  remote_cmd $loadbalancer systemctl restart haproxy
else
  sudo sed -i '/net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
  sudo echo 'net.ipv4.ip_nonlocal_bind=1' >>/etc/sysctl.conf
  sudo sysctl -p
  sudo systemctl daemon-reload
  sudo systemctl enable haproxy
  sudo systemctl restart haproxy
fi
prnt "Started haproxy on $loadbalancer"
