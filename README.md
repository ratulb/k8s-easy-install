# k8s-easy-install
Setup a kubernetes cluster by running a simple script(Ansible is great and we love it but here we do without it) fronted by haproxy/nginx/envoy loadbalancer.

Take the hassle out of logging into each machine to install containerd, kube components & network plugin. Instead manage everything from a single machine.The machine from where the script is launched can be a part of the cluster too. 

Add the the current machine's SSH public key to the ~/.ssh/authorized_keys of the cluster machins(only for multi-node cluster).

How to setup:

Check this repository out. 

git clone https://github.com/ratulb/k8s-easy-install.git -b containerd-main


cd k8s-easy-install && ./cluster.sh

Follow the menu driven options to create a single master or multi-master cluster.

These steps have been verified on debian buster and Ubuntu 16.04/18.04/20.04.

Cross reference: http://rbsomeg.blogspot.com/2021/01/multi-master-kubernetes-on-containerd.html


