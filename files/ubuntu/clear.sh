#!/bin/bash
PURGE='apt-get -y --auto-remove purge'

$PURGE python-keystoneclient
$PURGE nova-common
$PURGE quantum-common
$PURGE openstack-dashboard apache2
$PURGE cinder-common
$PURGE glance-common
$PURGE openvswitch-common
$PURGE mysql-common
$PURGE rabbitmq-server erlang-base
$PURGE qemu-kvm
$PURGE ntp

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
rm -rf /var/lib/nova
rm -rf /var/lib/instances
rm -rf /var/lib/cinder
rm -rf /var/lib/cinder-volumes

rm -rf /var/chef/cache

ifconfig eth1 0 down
ifconfig eth2 0 down

service chef-client stop
