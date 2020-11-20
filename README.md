# k8s-remote-install
Install a kubernetes cluster remotely

Take the hassle out of logging into each machine install docker, install kubernetes components. Instead manage everything from a remote machine running a few scripts.The machine from where the script is launched can be a part of the cluster. Multi-master cluster is not supported currently.

All that is required is the managing server's SSH public key should be added to the /root/.ssh/authorized_keys of the cluster machins.

How to setup:

Check out this repository. Edit setup.conf for master and worker nodes and then run the following script:

./launch-cluster.sh

And the cluster should be up and running. Has been tested for ubuntu18.04.

