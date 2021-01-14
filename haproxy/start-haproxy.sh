#!/usr/bin/env bash
. utils.sh

print_msg "Starting haproxy on $loadbalancer"
if [ "$this_host_ip" != "$loadbalancer" ]; then
  . execute-command-remote.sh $loadbalancer sed -i '/net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
  . execute-command-remote.sh $loadbalancer echo 'net.ipv4.ip_nonlocal_bind=1' >>/etc/sysctl.conf
  . execute-command-remote.sh $loadbalancer sysctl -p
  . execute-command-remote.sh $loadbalancer systemctl daemon-reload
  . execute-command-remote.sh $loadbalancer systemctl stop haproxy
  . execute-command-remote.sh $loadbalancer systemctl enable haproxy
  . execute-command-remote.sh $loadbalancer systemctl start haproxy
else
  sudo sed -i '/net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
  sudo echo 'net.ipv4.ip_nonlocal_bind=1' >>/etc/sysctl.conf
  sudo sysctl -p
  sudo systemctl daemon-reload
  sudo systemctl stop haproxy
  sudo systemctl enable haproxy
  sudo systemctl start haproxy
fi
