# -*- mode: ruby -*-

# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "madorn/trusty64"

# Begin node1
  config.vm.define "node1" do |node1|
    node1.vm.hostname = "controller"

    node1.vm.provider "vmware_fusion" do |vf, override|
	override.vm.network "private_network", ip: "172.16.99.100"
        vf.vmx["numvcpus"] = "1"
        vf.vmx["memsize"] = "1024"
        vf.vmx["vhv.enable"] = "TRUE"
	vf.vmx["ethernet1.present"] = "TRUE"
    	vf.vmx["ethernet1.connectionType"] = "hostonly"
    	vf.vmx["ethernet1.virtualDev"] = "e1000"
    	vf.vmx["ethernet1.wakeOnPcktRcv"] = "FALSE"
    	vf.vmx["ethernet1.addressType"] = "generated"
	vf.vmx["ethernet1.vnet"]  = "vmnet1"
        end

   node1.vm.provider "virtualbox" do |vb, override|
	override.vm.network "private_network", ip: "192.168.56.56"
        vb.customize [ "modifyvm", :id, "--cpus", "1" ]
        vb.customize [ "modifyvm", :id, "--memory", "1024" ]
	vb.customize [ "modifyvm", :id, "--hostonlyadapter2", "vboxnet0"]
   end
   node1.vm.provision :shell, path: "controller.sh"
end
# End node1

# Begin node2
  config.vm.define "node2" do |node2|
    node2.vm.hostname = "network"
    node2.vm.provider "vmware_fusion" do |vf, override|
        override.vm.network "private_network", ip: "172.16.99.101"
	override.vm.network "private_network", type: "dhcp"
        vf.vmx["numvcpus"] = "1"
        vf.vmx["memsize"] = "1024"
        vf.vmx["vhv.enable"] = "TRUE"
        vf.vmx["ethernet1.present"] = "TRUE"
        vf.vmx["ethernet1.connectionType"] = "hostonly"
        vf.vmx["ethernet1.virtualDev"] = "e1000"
        vf.vmx["ethernet1.wakeOnPcktRcv"] = "FALSE"
        vf.vmx["ethernet1.addressType"] = "generated"
        vf.vmx["ethernet1.vnet"]  = "vmnet1"
        vf.vmx["ethernet2.present"] = "TRUE"
        vf.vmx["ethernet2.connectionType"] = "nat"
        vf.vmx["ethernet2.virtualDev"] = "e1000"
        vf.vmx["ethernet2.addressType"] = "generated"
	end

   node2.vm.provider "virtualbox" do |vb, override|
        override.vm.network "private_network", ip: "192.168.56.57"
        override.vm.network "private_network", type: "dhcp"
        vb.customize [ "modifyvm", :id, "--cpus", "1" ]
        vb.customize [ "modifyvm", :id, "--memory", "1024" ]
        vb.customize [ "modifyvm", :id, "--hostonlyadapter2", "vboxnet0"]
        vb.customize [ "modifyvm", :id, "--nic3", "nat"]
  end
  node2.vm.provision :shell, path: "network.sh"
end
# End node2

# Begin node3
  config.vm.define "node3" do |node3|
    node3.vm.hostname = "compute"
    
node3.vm.provider "vmware_fusion" do |vf, override|
        override.vm.network "private_network", ip: "172.16.99.102"
        vf.vmx["numvcpus"] = "1"
        vf.vmx["memsize"] = "1024"
        vf.vmx["vhv.enable"] = "TRUE"
        vf.vmx["ethernet1.present"] = "TRUE"
        vf.vmx["ethernet1.connectionType"] = "hostonly"
        vf.vmx["ethernet1.virtualDev"] = "e1000"
        vf.vmx["ethernet1.wakeOnPcktRcv"] = "FALSE"
        vf.vmx["ethernet1.addressType"] = "generated"
        vf.vmx["ethernet1.vnet"]  = "vmnet1"
        end

   node3.vm.provider "virtualbox" do |vb, override|
        override.vm.network "private_network", ip: "192.168.56.58"
        vb.customize [ "modifyvm", :id, "--cpus", "1" ]
        vb.customize [ "modifyvm", :id, "--memory", "1024" ]
        vb.customize [ "modifyvm", :id, "--hostonlyadapter2", "vboxnet0"]
    end
    node3.vm.provision :shell, path: "compute.sh"
end
end
# End node3
