# k8s-remote-install
Install a kubernetes cluster remotely via a single script.

Take the hassle out of logging into each machine install docker, install kubernetes components. Instead manage everything from a remote machine.The machine from where the script is launched can be a part of the cluster too. Multi-master cluster is not supported currently.

All that is required is the managing server's SSH public key should be added to the /root/.ssh/authorized_keys of the cluster machins.

How to setup:

Check out this repository. 

git clone https://github.com/ratulb/k8s-remote-install.git

Edit setup.conf for master and worker nodes and then run the following script:

vi setup.conf

./launch-cluster.sh

And the cluster should be up and running with a nginx pod deployed on the cluster. Has been tested for ubuntu 16.04/18.04/20.04.1.



