OpenStack Juno Deployment with Vagrant (Linux-Bridge + VXLAN)
==============================================================
Features
------------
* Three Nodes (Controller, Network, Compute) - Ubuntu 14.04
* Linux-Bridge with VXLAN tunneling
* Works with VMware Fusion or VirtualBox
* Network node includes internet gateway (eth2 buried into br-ex bridge)

Minimum Requirements
---------------------
* [Vagrant](http://www.vagrantup.com)
* 8GB hard drive space
* At least 3GB RAM to allocate to environment

Get Started
------------
**Clone the Git repo** <br /> 

``git clone https://github.com/madorn/vagrant-juno-linuxbridge-vxlan.git`` <br /> 

**For VirtualBox** <br />
Verify that you have default host-only vboxnet0 network (192.168.56.0/24) <br />

``vagrant up --provider virtualbox --provision``

**For VMware Fusion** <br />
Verify that you have default host-only vmnet1 network (172.16.99.0/24) <br />

``vagrant up --provider vmware_fusion --provision``

**Horizon Dashboard** <br />
``http://192.168.56.56/horizon`` (VirtualBox)<br />
``http://172.16.99.100/horizon`` (VMware Fusion)

**SSH into node1** <br />

``vagrant ssh node1``

**Switch to Root**

``su -`` password: vagrant

**Source credentials**

``source ~/credentials/admin``

**Create a private network prior to booting instance** <br />

``neutron net-create private`` <br />

``neutron subnet-create --name private-subnet <private_network_id> 10.0.0.0/29``

**Boot Instance**

``nova boot --flavor 1 --image cirros-qcow2 myinstance``

**Enable ping and SSH**

``neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 10.0.0.0/24 default``

``neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 10.0.0.0/24 default``

**Create an external network for the internet gateway (VirtualBox)** <br /> 

``neutron net-create public --router:external True --provider:network_type flat --provider:physical_network physnet1``<br /> 

``neutron subnet-create --name public-subnet --gateway 10.0.4.2 --allocation-pool start=10.0.4.100,end=10.0.4.200 --disable-dhcp public 10.0.4.0/24``

**Create an external network for the internet gateway (VMware Fusion)** <br /> 

``neutron net-create public --router:external True --provider:network_type flat --provider:physical_network physnet1``<br /> 

``neutron subnet-create --name public-subnet --gateway 192.168.13.2 --allocation-pool start=192.168.13.100,end=192.168.13.200 --disable-dhcp public 192.168.13.0/24``

**Create a router**

``neutron router-create myrouter``

**Add private-network to the router**

``neutron router-interface-add myrouter <private-subnet_id>``

**Set public-network as the default gateway**

``neutron router-gateway-set myrouter <public-network_id>``
