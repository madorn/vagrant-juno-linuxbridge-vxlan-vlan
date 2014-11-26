#!/bin/bash -eux

### Configuration

export MY_IP=172.16.99.100
export RABBITMQ_IP=172.16.99.100
export MYSQL_IP=172.16.99.100
export KEYSTONE_IP=172.16.99.100
export GLANCE_IP=172.16.99.100
export NEUTRON_IP=172.16.99.100
export NOVA_IP=172.16.99.100
export CINDER_IP=172.16.99.100
export HORIZON_IP=172.16.99.100

### Synchronize time

sudo ntpdate -u ntp.ubuntu.com | true

### Create creds file

mkdir ~/credentials

cat <<EOF | sudo tee ~/credentials/user
export OS_USERNAME=myuser
export OS_PASSWORD=mypassword
export OS_TENANT_NAME=MyProject
export OS_AUTH_URL=http://$MY_IP:5000/v2.0/
export OS_REGION_NAME=RegionOne
EOF

cat <<EOF | sudo tee ~/credentials/admin
export OS_USERNAME=myadmin
export OS_PASSWORD=mypassword
export OS_TENANT_NAME=MyProject
export OS_AUTH_URL=http://$MY_IP:5000/v2.0/
export OS_REGION_NAME=RegionOne
EOF

### Juno

sudo apt-get install -y ubuntu-cloud-keyring software-properties-common

sudo add-apt-repository -y cloud-archive:juno

sudo apt-get update

### RabbitMQ

sudo apt-get install -y rabbitmq-server

sudo mkdir /etc/rabbitmq/rabbitmq.conf.d
cat <<EOF | sudo tee /etc/rabbitmq/rabbitmq.conf.d/rabbitmq-listen.conf
RABBITMQ_NODE_IP_ADDRESS=$RABBITMQ_IP
EOF
sudo chmod 644 /etc/rabbitmq/rabbitmq.conf.d/rabbitmq-listen.conf

sudo service rabbitmq-server restart

### MariaDB

cat <<EOF | sudo debconf-set-selections
mysql-server-5.1 mysql-server/root_password password notmysql
mysql-server-5.1 mysql-server/root_password_again password notmysql
mysql-server-5.1 mysql-server/start_on_boot boolean true
EOF

sudo apt-get install -y mariadb-server python-mysqldb

sudo sed -i "s/127.0.0.1/$MYSQL_IP\ndefault-storage-engine = innodb\ninnodb_file_per_table\ncollation-server = utf8_general_ci\ncharacter-set-server = utf8\\ninit-connect = 'SET NAMES utf8'/g" /etc/mysql/my.cnf

sudo service mysql restart

### Keystone

sudo apt-get install -y keystone

sudo service keystone stop

mysql -u root -pnotmysql -e "CREATE DATABASE keystone;"
mysql -u root -pnotmysql -e "GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'notkeystone';"
mysql -u root -pnotmysql -e "GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'notkeystone';"

sudo sed -i "s|connection=sqlite:////var/lib/keystone/keystone.db|connection=mysql://keystone:notkeystone@$MYSQL_IP/keystone|g" /etc/keystone/keystone.conf

sudo keystone-manage db_sync

sudo service keystone start
sleep 15

export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://$KEYSTONE_IP:35357/v2.0

keystone tenant-create --name MyProject
TENANT_ID=`keystone tenant-get MyProject | awk '/ id / { print $4 }'`
keystone tenant-create --name Services
SERVICE_TENANT_ID=`keystone tenant-get Services | awk '/ id / { print $4 }'`
keystone role-create --name admin
ADMIN_ROLE_ID=`keystone role-get admin | awk '/ id / { print $4 }'`
keystone user-create --tenant-id $TENANT_ID --name myuser --pass mypassword
MEMBER_USER_ID=`keystone user-get myuser | awk '/ id / { print $4 }'`
keystone user-create --tenant-id $TENANT_ID --name myadmin --pass mypassword
ADMIN_USER_ID=`keystone user-get myadmin | awk '/ id / { print $4 }'`
keystone user-role-add --user-id $ADMIN_USER_ID --tenant-id $TENANT_ID --role-id $ADMIN_ROLE_ID

keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
KEYSTONE_SVC_ID=`keystone service-get keystone | awk '/ id / { print $4 }'`
keystone endpoint-create --region RegionOne --service-id=$KEYSTONE_SVC_ID --publicurl=http://$KEYSTONE_IP:5000/v2.0 --internalurl=http://$KEYSTONE_IP:5000/v2.0 --adminurl=http://$KEYSTONE_IP:35357/v2.0

### Glance

sudo apt-get install -y glance

sudo service glance-api stop
sudo service glance-registry stop

keystone user-create --tenant-id $SERVICE_TENANT_ID --name glance --pass notglance
GLANCE_USER_ID=`keystone user-get glance | awk '/ id / { print $4 }'`
keystone user-role-add --user-id $GLANCE_USER_ID --tenant-id $SERVICE_TENANT_ID --role-id $ADMIN_ROLE_ID

keystone service-create --name=glance --type=image --description="Glance Image Service"
GLANCE_SVC_ID=`keystone service-get glance | awk '/ id / { print $4 }'`
keystone endpoint-create --region RegionOne --service-id=$GLANCE_SVC_ID --publicurl=http://$GLANCE_IP:9292/v1 --internalurl=http://$GLANCE_IP:9292/v1 --adminurl=http://$GLANCE_IP:9292/v1

mysql -u root -pnotmysql -e "CREATE DATABASE glance;"
mysql -u root -pnotmysql -e "GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'notglance';"
mysql -u root -pnotmysql -e "GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY 'notglance';"

# Configure Glance-API
sudo sed -i "s|#connection = <None>|connection = mysql://glance:notglance@$MY_IP/glance|g" /etc/glance/glance-api.conf
sudo sed -i "s/rabbit_host = localhost/rabbit_host = $RABBITMQ_IP/g" /etc/glance/glance-api.conf
sudo sed -i "s/identity_uri = http:\/\/127.0.0.1:35357/identity_uri = http:\/\/$KEYSTONE_IP:35357/g" /etc/glance/glance-api.conf
sudo sed -i 's/%SERVICE_TENANT_NAME%/Services/g' /etc/glance/glance-api.conf
sudo sed -i 's/%SERVICE_USER%/glance/g' /etc/glance/glance-api.conf
sudo sed -i 's/%SERVICE_PASSWORD%/notglance/g' /etc/glance/glance-api.conf
sudo sed -i 's/#flavor=/flavor = keystone/g' /etc/glance/glance-api.conf
sudo sed -i 's/#show_image_direct_url = False/show_image_direct_url = True/g' /etc/glance/glance-api.conf
sudo sed -i "s|#connection = <None>|connection = mysql://glance:notglance@$MYSQL_IP/glance|g" /etc/glance/glance-registry.conf
sudo sed -i "s/identity_uri = http:\/\/127.0.0.1:35357/identity_uri = http:\/\/$KEYSTONE_IP:35357/g" /etc/glance/glance-registry.conf
sudo sed -i 's/%SERVICE_TENANT_NAME%/Services/g' /etc/glance/glance-registry.conf
sudo sed -i 's/%SERVICE_USER%/glance/g' /etc/glance/glance-registry.conf
sudo sed -i 's/%SERVICE_PASSWORD%/notglance/g' /etc/glance/glance-registry.conf
sudo sed -i 's/#flavor=/flavor = keystone/g' /etc/glance/glance-registry.conf

sudo glance-manage db_sync

sudo service glance-registry start
sudo service glance-api start

export OS_USERNAME=glance
export OS_PASSWORD=notglance
export OS_TENANT_NAME=Services
export OS_AUTH_URL=http://$KEYSTONE_IP:5000/v2.0/
export OS_REGION_NAME=RegionOne

mkdir ~/images
wget http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img -O ~/images/cirros-0.3.3-x86_64-disk.img

glance image-create --name "cirros-qcow2" --disk-format qcow2 --container-format bare --is-public True --file ~/images/cirros-0.3.3-x86_64-disk.img

### Nova

sudo apt-get install -y nova-api nova-scheduler nova-conductor nova-cert nova-consoleauth nova-novncproxy

sudo service nova-api stop
sudo service nova-scheduler stop
sudo service nova-conductor stop
sudo service nova-cert stop
sudo service nova-consoleauth stop
sudo service nova-novncproxy stop

keystone user-create --tenant-id $SERVICE_TENANT_ID --name nova --pass notnova
NOVA_USER_ID=`keystone user-get nova | awk '/ id / { print $4 }'`
keystone user-role-add --user-id $NOVA_USER_ID --tenant-id $SERVICE_TENANT_ID --role-id $ADMIN_ROLE_ID

keystone service-create --name=nova --type=compute --description="Nova Compute Service"
NOVA_SVC_ID=`keystone service-get nova | awk '/ id / { print $4 }'`
keystone endpoint-create --region RegionOne --service-id=$NOVA_SVC_ID --publicurl="http://$NOVA_IP:8774/v2/%(tenant_id)s" --internalurl="http://$NOVA_IP:8774/v2/%(tenant_id)s" --adminurl="http://$NOVA_IP:8774/v2/%(tenant_id)s"

mysql -u root -pnotmysql -e "CREATE DATABASE nova;"
mysql -u root -pnotmysql -e "GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'notnova';"
mysql -u root -pnotmysql -e "GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY 'notnova';"

cat <<EOF | sudo tee -a /etc/nova/nova.conf
network_api_class=nova.network.neutronv2.api.API
neutron_url=http://$NEUTRON_IP:9696
neutron_auth_strategy=keystone
neutron_admin_tenant_name=Services
neutron_admin_username=neutron
neutron_admin_password=notneutron
neutron_admin_auth_url=http://$KEYSTONE_IP:35357/v2.0
firewall_driver=nova.virt.firewall.NoopFirewallDriver
security_group_api=neutron
linuxnet_interface_driver=nova.network.linux_net.LinuxBridgeInterfaceDriver
rabbit_host=$RABBITMQ_IP
glance_host=$GLANCE_IP
auth_strategy=keystone
force_config_drive=always
my_ip=$MY_IP
fixed_ip_disassociate_timeout=30
enable_instance_password=False
service_neutron_metadata_proxy=True
neutron_metadata_proxy_shared_secret=openstack
novncproxy_base_url=http://$HORIZON_IP:6080/vnc_auto.html
vncserver_proxyclient_address=$MY_IP
vncserver_listen=0.0.0.0

[database]
connection=mysql://nova:notnova@$MYSQL_IP/nova

[keystone_authtoken]
auth_uri = http://$KEYSTONE_IP:5000
auth_host = $KEYSTONE_IP
auth_port = 35357
auth_protocol = http
admin_tenant_name = Services
admin_user = nova
admin_password = notnova
EOF

sudo nova-manage db sync

sudo service nova-api start
sudo service nova-scheduler start
sudo service nova-conductor start
sudo service nova-cert start
sudo service nova-consoleauth start
sudo service nova-novncproxy start

### Neutron

sudo apt-get install -y neutron-server neutron-plugin-ml2

sudo service neutron-server stop

keystone user-create --tenant-id $SERVICE_TENANT_ID --name neutron --pass notneutron
NEUTRON_USER_ID=`keystone user-get neutron | awk '/ id / { print $4 }'`
keystone user-role-add --user-id $NEUTRON_USER_ID --tenant-id $SERVICE_TENANT_ID --role-id $ADMIN_ROLE_ID

keystone service-create --name=neutron --type=network --description="Neutron Network Service"
NEUTRON_SVC_ID=`keystone service-get neutron | awk '/ id / { print $4 }'`
keystone endpoint-create --region RegionOne --service-id=$NEUTRON_SVC_ID --publicurl=http://$NEUTRON_IP:9696 --internalurl=http://$NEUTRON_IP:9696 --adminurl=http://$NEUTRON_IP:9696

mysql -u root -pnotmysql -e "CREATE DATABASE neutron;"
mysql -u root -pnotmysql -e "GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'notneutron';"
mysql -u root -pnotmysql -e "GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'notneutron';"

sudo sed -i "s|connection = sqlite:////var/lib/neutron/neutron.sqlite|connection = mysql://neutron:notneutron@$MYSQL_IP/neutron|g" /etc/neutron/neutron.conf
sudo sed -i "s/#rabbit_host=localhost/rabbit_host=$RABBITMQ_IP/g" /etc/neutron/neutron.conf
sudo sed -i 's/# allow_overlapping_ips = False/allow_overlapping_ips = True/g' /etc/neutron/neutron.conf
sudo sed -i 's/# service_plugins =/service_plugins = router/g' /etc/neutron/neutron.conf
sudo sed -i 's/# auth_strategy = keystone/auth_strategy = keystone/g' /etc/neutron/neutron.conf
sudo sed -i "s/auth_host = 127.0.0.1/auth_host = $KEYSTONE_IP/g" /etc/neutron/neutron.conf
sudo sed -i 's/%SERVICE_TENANT_NAME%/Services/g' /etc/neutron/neutron.conf
sudo sed -i 's/%SERVICE_USER%/neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/%SERVICE_PASSWORD%/notneutron/g' /etc/neutron/neutron.conf
sudo sed -i "s|# nova_url = http://127.0.0.1:8774\(\/v2\)\?|nova_url = http://$NOVA_IP:8774/v2|g" /etc/neutron/neutron.conf
sudo sed -i "s/# nova_admin_username =/nova_admin_username = nova/g" /etc/neutron/neutron.conf
sudo sed -i "s/# nova_admin_tenant_id =/nova_admin_tenant_id = $SERVICE_TENANT_ID/g" /etc/neutron/neutron.conf
sudo sed -i "s/# nova_admin_password =/nova_admin_password = notnova/g" /etc/neutron/neutron.conf
sudo sed -i "s|# nova_admin_auth_url =|nova_admin_auth_url = http://$KEYSTONE_IP:35357/v2.0|g" /etc/neutron/neutron.conf

# Configure Neutron ML2
sudo sed -i 's|# type_drivers = local,flat,vlan,gre,vxlan|type_drivers = vxlan,flat|g' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's|# tenant_network_types = local|tenant_network_types = vxlan,flat|g' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's|# mechanism_drivers =|mechanism_drivers = linuxbridge,l2population|g' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's|# flat_networks =|flat_networks = physnet1|g' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's|# vni_ranges =|vni_ranges = 100:200|g' /etc/neutron/plugins/ml2/ml2_conf.ini
sudo sed -i 's|# enable_security_group = True|firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver\nenable_security_group = True|g' /etc/neutron/plugins/ml2/ml2_conf.ini

# Configure Neutron ML2 continued...
( cat | sudo tee -a /etc/neutron/plugins/ml2/ml2_conf.ini ) <<EOF

[agent]
l2population = True
tunnel_type = vxlan

[linuxbridge]
physical_interface_mappings = physnet1:br-ex

[l2pop]
agent_boot_time = 180

[vxlan]
enable_vxlan = True
local_ip = $MY_IP
l2_population = True
EOF

sudo neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno

sudo service neutron-server start
sleep 15

source ~/credentials/user

neutron net-create private
PRIVATE_NET_ID=`neutron net-show private | awk '/ id / { print $4 }'`
neutron subnet-create --name private-subnet1 $PRIVATE_NET_ID 10.0.0.0/29
PRIVATE_SUBNET1_ID=`neutron subnet-show private-subnet1 | awk '/ id / { print $4 }'`

### Cinder

sudo apt-get install -y cinder-api cinder-scheduler

sudo service cinder-api stop
sudo service cinder-scheduler stop

source ~/credentials/admin

keystone user-create --tenant-id $SERVICE_TENANT_ID --name cinder --pass notcinder
CINDER_USER_ID=`keystone user-get cinder | awk '/ id / { print $4 }'`
keystone user-role-add --user-id $CINDER_USER_ID --tenant-id $SERVICE_TENANT_ID --role-id $ADMIN_ROLE_ID

keystone service-create --name=cinder --type=volume --description="Cinder Volume Service"
CINDER_SVC_ID=`keystone service-get cinder | awk '/ id / { print $4 }'`

keystone endpoint-create --region RegionOne --service-id=$CINDER_SVC_ID --publicurl="http://$CINDER_IP:8776/v1/%(tenant_id)s" --internalurl="http://$CINDER_IP:8776/v1/%(tenant_id)s" --adminurl="http://$CINDER_IP:8776/v1/%(tenant_id)s"

mysql -u root -pnotmysql -e "CREATE DATABASE cinder;"
mysql -u root -pnotmysql -e "GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'notcinder';"
mysql -u root -pnotmysql -e "GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'notcinder';"

( cat | sudo tee -a /etc/cinder/cinder.conf ) <<EOF
my_ip = $MY_IP
rabbit_host = $RABBITMQ_IP
glance_host = $GLANCE_IP
control_exchange = cinder
notification_driver = cinder.openstack.common.notifier.rpc_notifier
enabled_backends=cinder-volumes-sata-backend,cinder-volumes-ssd-backend

[database]
connection = mysql://cinder:notcinder@$MYSQL_IP/cinder

[cinder-volumes-sata-backend]
volume_group=cinder-volumes-sata
volume_driver=cinder.volume.drivers.lvm.LVMISCSIDriver
volume_backend_name=sata

[cinder-volumes-ssd-backend]
volume_group=cinder-volumes-ssd
volume_driver=cinder.volume.drivers.lvm.LVMISCSIDriver
volume_backend_name=ssd

[keystone_authtoken]
auth_uri = http://$KEYSTONE_IP:5000
auth_host = $KEYSTONE_IP
auth_port = 35357
auth_protocol = http
admin_tenant_name = Services
admin_user = cinder
admin_password = notcinder
EOF

sudo cinder-manage db sync

sudo service cinder-scheduler start
sudo service cinder-api start
sleep 15

export OS_USERNAME=cinder
export OS_PASSWORD=notcinder
export OS_TENANT_NAME=Services
export OS_AUTH_URL=http://$KEYSTONE_IP:5000/v2.0/
export OS_REGION_NAME=RegionOne

cinder type-create SATA
cinder type-key SATA set volume_backend_name=sata
cinder type-create SSD
cinder type-key SSD set volume_backend_name=ssd

unset OS_USERNAME
unset OS_PASSWORD
unset OS_TENANT_NAME
unset OS_AUTH_URL
unset OS_REGION_NAME

### Horizon

sudo apt-get install -y --no-install-recommends memcached openstack-dashboard

sudo service apache2 restart
