print_msg "Installing kubemaster load balancer on $loadbalancer"
if [ "$this_host_ip" = "$loadbalancer" ]; then
  . envoy/install-envoy.script
else
  . execute-script-remote.sh $loadbalancer envoy/install-envoy.script
fi

echo -e "\e[1;32mInstalled envoy on $loadbalancer\e[0m"
