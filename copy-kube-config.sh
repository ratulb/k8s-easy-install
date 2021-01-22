#!/usr/bin/env bash
. utils.sh

case $1 in
  from)
    mkdir -p $HOME/.kube/
    echo "check1"
    remote_copy $2:/etc/kubernetes/admin.conf $HOME/.kube/config
    echo "check2"
    chown $(id -u):$(id -g) $HOME/.kube/config
    sed -i '/source <(kubectl completion bash)/d' $HOME/.bashrc
    echo 'source <(kubectl completion bash)' >>$HOME/.bashrc
    source $HOME/.bashrc

    echo "check3"
    ;;
  to)
    remote_cmd $2 mkdir -p $HOME/.kube
    remote_copy $HOME/.kube/config $2:$HOME/.kube/config
    remote_cmd $2 chown $(id -u):$(id -g) $HOME/.kube/config
    remote_cmd $2 "sed -i '/source <(kubectl completion bash)/d'" $HOME/.bashrc
    remote_cmd $2 "echo 'source <(kubectl completion bash)'" >>$HOME/.bashrc
    ;;
  *) ;;
esac
