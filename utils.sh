#!/usr/bin/env bash 
export usr=$(whoami)
read_setup()
{
  file="$1"
  while IFS="=" read -r key value; do
    case "$key" in
      "master") export master="$value" ;;
      "workers") export workers="$value" ;;
      "#"*) ;;

    esac
  done < "$file"
}
