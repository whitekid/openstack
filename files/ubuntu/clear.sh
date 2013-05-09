#!/bin/bash
PURGE='apt-get -y --auto-remove purge'

$PURGE keystone nova-common quantum-common openstack-dashboard apache2 cinder-common glance-common openvswitch-common mysql-common
$PURGE qemu-kvm

rm -rf /var/lib/mysql /var/cache/local/preseeding/mysql-server.seed
rm -rf /etc/keystone
rm -rf /var/lib/mysql
rm -rf /etc/mysql
rm -rf /var/cache/local/preseeding/mysql-server.seed
rm -rf /etc/glance
rm -rf /var/lib/glance
rm -rf /var/lib/quantum
rm -rf /var/lib/keystone
rm -rf /etc/quantum
rm -rf /etc/openvswitch
rm -rf /etc/apt/sources.list.d/openstack*
rm -rf /etc/cinder
losetup -d /dev/loop0
rm -rf /var/lib/instances
rm -rf /var/lib/cinder
rm -rf /var/lib/cinder-volumes

rm -rf /var/chef/cache

ifconfig eth1 0 down
ifconfig eth2 0 down
