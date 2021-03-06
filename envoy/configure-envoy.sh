#!/usr/bin/env bash

. utils.sh

rm -f /tmp/backends.txt
touch /tmp/backends.txt
for _master in $masters; do
  echo "        - endpoint:">>/tmp/backends.txt
  echo "            address:" >>/tmp/backends.txt
  echo "              socket_address:" >>/tmp/backends.txt
  echo "                address: $_master" >>/tmp/backends.txt
  echo "                port_value: 6443" >>/tmp/backends.txt
done

first_entry=$(echo $masters | cut -d' ' -f1)
cp envoy/envoy-template-1.yaml envoy.draft
if is_ip $first_entry; then
  sed -i "s/#dns_type#/STATIC/g" envoy.draft
else
  sed -i "s/#dns_type#/STRICT_DNS/g" envoy.draft
fi
sed -i "s/#lb_port#/$lb_port/g" envoy.draft

cat /tmp/backends.txt >> envoy.draft
cat envoy/envoy-template-2.yaml >> envoy.draft

if [[ "$this_host_ip" = "$loadbalancer" ]] || [[ "$this_host_name" = "$loadbalancer" ]]; then
  sudo mkdir -p /etc/envoy
  sudo cp envoy.draft /etc/envoy/envoy.yaml
  sudo cp envoy/envoy.service /etc/systemd/system/
else
  remote_cmd $loadbalancer mkdir -p /etc/envoy
  remote_copy envoy.draft $loadbalancer:/etc/envoy/envoy.yaml
  remote_copy envoy/envoy.service $loadbalancer:/etc/systemd/system/
fi

prnt "Configured envoy on $loadbalancer"
