## k8s-easy-install
#### Setup a kubernetes cluster by running a simple script(Ansible is great and we love it but here we do without it) fronted by haproxy/nginx/envoy loadbalancer.

Take the hassle out of logging into each machine to install containerd, kube components & network plugin. Instead manage everything from a single machine.The machine from where the script is launched can be a part of the cluster too. 

Add the the current machine's SSH public key to the ~/.ssh/authorized_keys of the cluster machins(only for multi-node cluster).

How to setup:

Check this repository out. 

git clone https://github.com/ratulb/k8s-easy-install.git


cd k8s-easy-install && ./cluster.sh

Follow the menu driven options to create a single master or multi-master cluster.

#### These steps have been verified on debian buster and Ubuntu 16.04/18.04/20.04.

#### Notes for single instance installation
By default - the installtion assumes a multi node cluster - where load balancer fronting the kube api servers is expected to be on a separate box. In a single node cluster where - load balancer, kube master and worker nodes are all in one box - we need to select a different port for the load balancer - by default it shows as [localhost ip]:6643.
For single node choose a different port > 1000;

Next, setup the master node - giving the ip address of the local host. Hit enter twice.

No worker nodes to be selected - all work loads would be on the same node.

So the sequence of cluster setup is:
- Load balancer
- Master node
- Launch

Don't hit enter - just press 'y'.


