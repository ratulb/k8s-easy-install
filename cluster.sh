#!/usr/bin/env bash
. utils.sh
clear
echo ""
prnt "kubernetes cluster setup"
declare -A setupActions
setupActions+=(['Quit']='quit')
setupActions+=(['Cluster setup']='cluster-setup')
setupActions+=(['Console']='console')
setupActions+=(['Containerd status']='containerd-status')
setupActions+=(['Kubelet status']='kubelet-status')
setupActions+=(['System pod status']='system-pod-status')
setupActions+=(['Load balancer status']='lb-status')
setupActions+=(['Refresh view']='refresh-view')
echo ""
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select option in "${!setupActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 8 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${setupActions[$option]}" in
      system-pod-status)
        . system-pod-status.sh
        ;;

      console)
        ./console.sh
        ;;

      cluster-setup)
        echo ""
        PS3=$'\e[01;32mMulti-master setup: \e[0m'
        multi_master_options=('Loadbalancer' 'Back' 'Launch' 'Master nodes' 'Worker nodes' 'Reset configuration')
        select multi_master_option in "${multi_master_options[@]}"; do
          if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 6 -o "$REPLY" -lt 1 ]; then
            err "Invalid selection!"
          else
            case "$multi_master_option" in
              'Loadbalancer')
                unset lb_addr_and_port
                rm -f /tmp/lb_addr_and_port.txt
                prnt "Loadbalancer[$(hostname -i):6443](q - quit, p - proceed with default)"
                read -p 'Address and port: ' lb_addr_and_port
                while [[ $lb_addr_and_port != 'q' ]] && [[ $lb_addr_and_port != 'p' ]] && ! lb_address_valid $lb_addr_and_port; do
                  read -p 'Address and port: ' lb_addr_and_port
                  [ "$lb_addr_and_port" = "p" ] && break
                  if [ "$lb_addr_and_port" = "q" ]; then
                    rm -f /tmp/lb_addr_and_port.txt
                    unset lb_addr_and_port
                    PS3=$'\e[01;32mSelection: \e[0m'
                    break 1
                  fi
                done
                if [ "$lb_addr_and_port" = 'q' ]; then
                  err "Cancelled"
                  echo ""
                  break
                fi
                if [ $lb_addr_and_port = 'p' ]; then
                  lb_addr_and_port=$(hostname -i):6443
                fi
                lb_address=$(echo $lb_addr_and_port | cut -d':' -f1)
                rm -f /tmp/lb_addr_and_port.txt
                if ! is_address_local $lb_address; then
                  prnt "Checking access to $lb_address"
                  if can_access_address $lb_address; then
                    rm -f /tmp/selected_lb_type.txt
                    echo "lb_addr_and_port=$lb_addr_and_port" >>/tmp/lb_addr_and_port.txt
                    prnt "Saved loadbalancer address and port"
                  else
                    err "$lb_address is not accesible. Has this machine's ssh key been addded to $lb_address?"
                    unset lb_address
                  fi
                else
                  echo "Chosen localhost($lb_address) as loadbalancer"
                  rm -f /tmp/selected_lb_type.txt
                  echo "lb_addr_and_port=$lb_addr_and_port" >>/tmp/lb_addr_and_port.txt
                  prnt "Saved loadbalancer address and port"
                fi
                if [ ! -z "$lb_address" ]; then
                  lb_choices=('haproxy' 'nginx' 'envoy')
                  PS3=$'\e[01;32mChoose loadbalancer(q - quit): \e[0m'
                  select lb_choice in "${lb_choices[@]}"; do
                    if [ "$REPLY" = "q" ]; then
                      err "Cancelled load balancer type selection"
                      rm -f /tmp/lb_addr_and_port.txt
                      break
                    fi
                    rm -f /tmp/selected_lb_type.txt
                    case "$lb_choice" in
                      'haproxy')
                        echo "Selected '$lb_choice' as api server loadbalancer"
                        echo "lb_type=$lb_choice" >>/tmp/selected_lb_type.txt
                        break
                        ;;
                      'nginx')
                        echo "Selected '$lb_choice' as api server loadbalancer"
                        echo "lb_type=$lb_choice" >>/tmp/selected_lb_type.txt
                        break
                        ;;
                      'envoy')
                        echo "Selected '$lb_choice' as api server loadbalancer"
                        echo "lb_type=$lb_choice" >>/tmp/selected_lb_type.txt
                        break
                        ;;
                      *)
                        err "Invalid selection"
                        ;;
                    esac
                  done
                fi
                echo ""
                PS3=$'\e[01;32mCluster setup: \e[0m'
                ;;

              'Master nodes')
                prnt "Type in the host or ip(s) api server master nodes - blank line to complete"
                rm -f /tmp/master-ips-cluster-setup.txt
                while read line; do
                  [ -z "$line" ] && break
                  echo "$line" >>/tmp/master-ips-cluster-setup.txt
                done
                unset multi_master_master_ips
                if [ -s /tmp/master-ips-cluster-setup.txt ]; then
                  multi_master_master_ips=$(cat /tmp/master-ips-cluster-setup.txt | tr "\n" " " | xargs)
                fi
                if [ -z "$multi_master_master_ips" ]; then
                  err "Empty master entries"
                else
                  unset valid_host_or_ips
                  unset invalid_host_or_ips
                  for host_or_ip in $multi_master_master_ips; do
                    if ! is_ip $host_or_ip && ! is_host_name_ok $host_or_ip; then
                      if [ -z "$invalid_host_or_ips" ]; then
                        invalid_host_or_ips=$host_or_ip
                      else
                        invalid_host_or_ips+=" $host_or_ip"
                      fi
                    else
                      if [ -z "$valid_host_or_ips" ]; then
                        valid_host_or_ips=$host_or_ip
                      else
                        valid_host_or_ips+=" $host_or_ip"
                      fi
                    fi
                  done
                  if [[ -z "$invalid_host_or_ips" ]] && [[ ! -z "$valid_host_or_ips" ]]; then
                    prnt "Checking access to $valid_host_or_ips"
                    unset not_accessibles
                    for _entry in $valid_host_or_ips; do
                      if ! can_access_address $_entry; then
                        not_accessibles+=" $_entry"
                      fi
                    done
                    not_accessibles=$(echo $not_accessibles | xargs)

                    if [ -z "$not_accessibles" ]; then
                      echo "Saving master entries $valid_host_or_ips"
                      valid_host_or_ips=$(echo $valid_host_or_ips | xargs -n1 | sort -u | xargs)
                      rm -f /tmp/master-ips-cluster-setup.txt
                      echo "masters=$valid_host_or_ips" >>/tmp/master-ips-cluster-setup.txt
                    else
                      err "Master(s) not accessible: $not_accessibles"
                      rm -f /tmp/master-ips-cluster-setup.txt
                    fi
                  else
                    err "Invalid master(s)"
                    rm -f /tmp/master-ips-cluster-setup.txt
                    [[ ! -z $invalid_host_or_ips ]] && echo $invalid_host_or_ips
                  fi
                fi
                echo ""
                PS3=$'\e[01;32mCluster setup: \e[0m'
                ;;

              'Worker nodes')
                prnt "Type in the host or ip(s)of worker nodes - blank line to complete"
                rm -f /tmp/worker-ips-cluster-setup.txt
                while read line; do
                  [ -z "$line" ] && break
                  echo "$line" >>/tmp/worker-ips-cluster-setup.txt
                done
                unset multi_master_worker_ips
                if [ -s /tmp/worker-ips-cluster-setup.txt ]; then
                  multi_master_worker_ips=$(cat /tmp/worker-ips-cluster-setup.txt | tr "\n" " " | xargs)
                fi
                if [ -z "$multi_master_worker_ips" ]; then
                  err "Empty worker entries"
                else
                  unset valid_host_or_ips
                  unset invalid_host_or_ips
                  for host_or_ip in $multi_master_worker_ips; do
                    if ! is_ip $host_or_ip && ! is_host_name_ok $host_or_ip; then
                      if [ -z "$invalid_host_or_ips" ]; then
                        invalid_host_or_ips=$host_or_ip
                      else
                        invalid_host_or_ips+=" $host_or_ip"
                      fi
                    else
                      if [ -z "$valid_host_or_ips" ]; then
                        valid_host_or_ips=$host_or_ip
                      else
                        valid_host_or_ips+=" $host_or_ip"
                      fi
                    fi
                  done
                  if [[ -z "$invalid_host_or_ips" ]] && [[ ! -z "$valid_host_or_ips" ]]; then
                    prnt "Checking access to $valid_host_or_ips"
                    unset not_accessibles
                    for _entry in $valid_host_or_ips; do
                      if ! can_access_address $_entry; then
                        not_accessibles+=" $_entry"
                      fi
                    done
                    not_accessibles=$(echo $not_accessibles | xargs)
                    if [ -z "$not_accessibles" ]; then
                      echo "Saving worker entries $valid_host_or_ips"
                      rm -f /tmp/worker-ips-cluster-setup.txt
                      valid_host_or_ips=$(echo $valid_host_or_ips | xargs -n1 | sort -u | xargs)
                      echo "workers=$valid_host_or_ips" >/tmp/worker-ips-cluster-setup.txt
                    else
                      err "Worker(s) not accessible: $not_accessibles"
                      rm -f /tmp/worker-ips-cluster-setup.txt
                    fi
                  else
                    err "Invalid worker(s)"
                    rm -f /tmp/worker-ips-cluster-setup.txt
                    [[ ! -z $invalid_host_or_ips ]] && echo $invalid_host_or_ips
                  fi
                fi

                echo ""
                PS3=$'\e[01;32mCluster setup: \e[0m'
                ;;
              'Back')
                echo "Exited multi-master setup"
                rm -f /tmp/selected_lb_type.txt
                rm -f /tmp/lb_addr_and_port.txt
                rm -f /tmp/master-ips-cluster-setup.txt
                rm -f /tmp/worker-ips-cluster-setup.txt
                echo ""
                break
                ;;
              'Reset configuration')
                . confirm-action.sh "Reset cluster configurations" "Cancelled reset"
                if [ "$?" -eq 0 ]; then
                  rm -f /tmp/selected_lb_type.txt
                  rm -f /tmp/lb_addr_and_port.txt
                  rm -f /tmp/master-ips-cluster-setup.txt
                  rm -f /tmp/worker-ips-cluster-setup.txt
                  reset_setup_configuration
                  read_setup
                  echo ""
                  prnt "Configurations have been reset"
                fi
                ;;

              'Launch')
                prnt "Checking saved configurations..."
                unset _lb_addr_
                unset _lb_port_
                unset _lb_type_
                unset _masters_
                unset _workers_
                proceed=true

                _file_=/tmp/master-ips-cluster-setup.txt
                if [ ! -s $_file_ ]; then
                  err "Master nodes configuration missing"
                  proceed=false
                else
                  _masters_=$(cat $_file_ | grep masters= | cut -d'=' -f2)
                  if [ -z "$_masters_" ]; then
                    err "No master nodes found"
                    proceed=false
                  fi
                fi

                _file_=/tmp/lb_addr_and_port.txt
                if [ ! -s $_file_ ]; then
                  warn "Loadbalancer address configuration missing"
                else
                  _lb_addr_=$(cat $_file_ | grep lb_addr_and_port= | cut -d'=' -f2 | cut -d':' -f1)
                  _lb_port_=$(cat $_file_ | grep lb_addr_and_port= | cut -d'=' -f2 | cut -d':' -f2)
                  if [[ -z "$_lb_addr_" ]] || [[ -z "$_lb_port_" ]]; then
                    warn "Loadbalancer address or port not valid"
                  fi
                fi
                _file_=/tmp/selected_lb_type.txt
                if [ ! -s $_file_ ]; then
                  warn "Loadbalancer type configuration missing"
                else
                  _lb_type_=$(cat $_file_ | grep lb_type= | cut -d'=' -f2)
                  if [ -z "$_lb_type_" ]; then
                    warn "Loadbalancer type is invalid"
                  fi
                fi
                _master_count=$(echo $masters | wc -w)
                if [[ "$_master_count" -gt 1 ]] && ([[ -z $_lb_addr_ ]] || [[ -z "$_lb_type_" ]] || [[ -z "$_lb_port_" ]]); then
                  err "For multi-master setup loadbalancer is needed - but configuration not correct"
                  proceed=false
                fi
                if ([[ ! -z "$_lb_addr_" ]] && ([[ -z "$_lb_type_" ]] || [[ -z "$_lb_port_" ]])) || ([[ ! -z "$_lb_type_" ]] && ([[ -z "$_lb_addr_" ]] || [[ -z "$_lb_port_" ]])) || ([[ ! -z "$_lb_port_" ]] && ([[ -z "$_lb_type_" ]] || [[ -z "$_lb_addr_" ]])); then
                  err "Loadbalancer configuration is not complete -2"
                  proceed=false
                fi

                _file_=/tmp/worker-ips-cluster-setup.txt
                if [ ! -s $_file_ ]; then
                  warn "Worker nodes configuration missing"
                else
                  _workers_=$(cat $_file_ | grep workers= | cut -d'=' -f2)
                  if [ -z "$_workers_" ]; then
                    warn "No worker nodes found"
                  fi
                fi
                if [ "$proceed" = "true" ]; then
                  validate_multi-master-configuration "$_lb_addr_" "$_lb_port_" "$_masters_" "$_workers_"
                  if [ "$?" -eq 0 ]; then
                    configure_multi_master_setup "$_lb_addr_" "$_lb_port_" "$_lb_type_" "$_masters_" "$_workers_"
                    if [ "$?" -eq 0 ]; then
                      read_setup
                      . confirm-action.sh "Proceed" "Cancelled cluster setup"
                      if [ "$?" -eq 0 ]; then
		        echo ""
                        read_setup
                        . launch-cluster.sh
                      fi
                    else
                      err "Configuration failure"
                    fi
                  else
                    err "Configuration validation failed"
                  fi

                else
                  err "One or more configurations are not valid - not proceeding with cluster launch"
                fi
                echo ""
                PS3=$'\e[01;32mSelection: \e[0m'
                ;;
            esac
          fi
        done
        ;;
      refresh-view)
        if [ "$0" = "-su" ]; then
          script="./cluster.sh"
        else
          script=$(readlink -f "$0")
        fi
        exec "$script"
        ;;
      quit)
        prnt "quit"
        rm -f /tmp/selected_lb_type.txt
        rm -f /tmp/lb_addr_and_port.txt
        rm -f /tmp/master-ips-cluster-setup.txt
        rm -f /tmp/worker-ips-cluster-setup.txt
        break
        ;;
      *)
        err "$option - This option has been disabled!"
        ;;
    esac
  fi
done
