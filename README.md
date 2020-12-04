# k8s-remote-install
Install a kubernetes cluster remotely via a single script.

Take the hassle out of logging into each machine install docker, kube components & network plugin. Instead manage everything from a single machine.The machine from where the script is launched can be a part of the cluster too. Multi-master cluster is not supported currently.

All that is required is the management server's SSH public key should be added to the ~/.ssh/authorized_keys of the cluster machins.

How to setup:

Check this repository out. 

git clone https://github.com/ratulb/k8s-remote-install.git

Edit setup.conf for master and worker nodes' IPs:

vi setup.conf

And then run the following script:

./launch-cluster.sh

And the cluster should be up and running with a nginx deployment. 

Tested for ubuntu 16.04/18.04/20.04.

Works on a cluster consisting of only a master node - but either master node's tain has to be removed or toleration has to be added to POD definitions for PODs to be deployable on a single node cluster. 

Cross reference: http://rbsomeg.blogspot.com/2020/11/setting-up-kubernetes-cluster-quickly.html


