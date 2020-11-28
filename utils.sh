#!/usr/bin/env bash 
export usr=$(whoami)
read_setup()
{
  while IFS="=" read -r key value; do
    case "$key" in
      "master") export master="$value" ;;
      "workers") export workers="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "#"*) ;;

    esac
  done < "setup.conf"
}

"read_setup"

print_msg()
{
 echo -e "\e[1;42m$1\e[0m"
}
#Whatever is the default sleep_time
sleep_few_secs()
{
 print_msg "Sleeping few secs..."
 sleep $sleep_time
}

#Launch busybox container called debug
k8_debug()
{
 kubectl run -i --tty --rm debug --image=busybox:1.28 --restart=Never -- sh 
}
