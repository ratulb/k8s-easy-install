#!/usr/bin/env bash

action=$1
abort_msg=$2

read -p "$action(y)? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  err "\n$abort_msg.\n"
  return 1
fi
