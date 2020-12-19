# k8s-easy-install
Setup a kubernetes cluster by running a simple script(Ansible is great and we love it but here we do without it).

Take the hassle out of logging into each machine to install docker(containerd based runtime lies in another branch), kube components & network plugin. Instead manage everything from a single machine.The machine from where the script is launched can be a part of the cluster too. 

Add the the current machine's SSH public key to the ~/.ssh/authorized_keys of the cluster machins(only for multi-node cluster).

How to setup:

Check this repository out. 

git clone https://github.com/ratulb/k8s-easy-install.git


cd k8s-easy-install && ./launch-cluster.sh (Single node cluster with localhost as master).

Or else:

Edit setup.conf for master and worker nodes' IPs:

vi setup.conf

And then run the following script:

./launch-cluster.sh

And the cluster should be up and running with a nginx deployment. 

These steps have been verified on Ubuntu 16.04/18.04/20.04.

Work in progress for multi-master cluster with seamless back and forth switch between embedded etcd and external etcd cluster.

Cross reference: http://rbsomeg.blogspot.com/2020/11/setting-up-kubernetes-cluster-ubuntu.html


