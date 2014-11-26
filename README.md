OpenStack Juno Deployment with Vagrant (LinuxBridge + VXLAN)
==============================================================
Features
------------
* Three Nodes (Controller, Network, Compute) - Ubuntu 14.04
* LinuxBridge with VXLAN tunneling
* Works with VMware Fusion or VirtualBox
* Network node includes internet gateway (eth2 buried into br-ex bridge)

Minimum Requirements
---------------------
* [Vagrant](http://www.vagrantup.com)
* 15GB hard drive space
* At least 3GB available RAM

Get Started
------------
**Clone the Git repo** <br /> 
``git clone https://github.com/madorn/vagrant-juno-linuxbridge-vxlan.git`` <br /> 

**For Virtualbox** <br />
Ensure you have default host-only vboxnet0 network (192.168.56.0/24) <br /> 
``vagrant up --provider virtualbox --provision``

**For Virtualbox** <br />
Ensure you have default host-only vmnet1 network (172.16.99.0/24) <br /> 
``vagrant up --provider vmware_fusion --provision``
