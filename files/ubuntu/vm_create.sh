#!/bin/bash
set -e

if [ -f `dirname $0`/vm_create.rc ]; then
	. `dirname $0`/vm_create.rc
fi

# Image for instance
TEMPLATE=${TEMPLATE:-cirros-0.3.1-x86_64}

# external subnet
EXTSUBNET=${EXTSUBNET:-10.100.1.128/25}

# tenant private subnet
PRISUBNET=${PRISUBNET:-172.16.0.0/16}

WITH_VOLUME=${WITH_VOLUME:-true}
WITH_FLOATINGIP=${WITH_FLOATINGIP:-true}
DNS=${DNS:-8.8.8.8}

if [ -z "$OS_TENANT_NAME" ]; then
	echo "openstack environ variables is not set"
	echo "please run . ~/openrc tenant_name"
	exit
fi

function usage(){
	echo "Usage: `basename $0` vmname"
	echo
	echo "	-c	clear all network items"
	echo "	-h	show this screen"
}

TENANT_ID=$(keystone tenant-list | grep " $OS_TENANT_NAME " | awk '{print $2}')
PRINET="${OS_TENANT_NAME}"
EXTNET="ext_net"

while getopts "hct:" opt; do
	case $opt in
		h)
			usage
			exit
			;;

		c)
			# clear all instance and networks
			[[ ! -z `nova list` ]] && \
				nova list | head -n -1 | tail -n +4 | awk '{print $2}' | xargs -L1 nova delete
			[[ ! -z `quantum floatingip-list` ]] && \
				quantum floatingip-list | head -n -1 | tail -n +4 | awk '{print $2}' | xargs -L1 quantum floatingip-delete
			[[ ! -z `quantum router-list` ]] && \
				quantum router-list | head -n -1 | tail -n +4 | awk '{print $2}' | xargs -L1 quantum router-gateway-clear
			if [[ ! -z `quantum port-list -- --device_owner network:router_interface` ]]; then
				for port_id in `quantum port-list -- --device_owner network:router_interface | head -n -1 | tail -n +4 | awk '{print $2}'`; do
					router_id=$(quantum port-show $port_id | grep 'device_id' | awk '{print $4}')
					subnet_id=$(quantum port-show 4c899c60-07f7-42af-bdc4-a3a8923a6f03 | grep 'fixed_ips' | awk '{print $5}' | tr -d ',' | tr -d '"')
					quantum router-interface-delete $router_id $subnet_id
				done
			fi
			[[ ! -z `quantum subnet-list` ]] && \
				quantum subnet-list | head -n -1 | tail -n +4 | awk '{print $2}' | xargs -L1 quantum subnet-delete || true
			[[ ! -z `quantum net-list` ]] && \
				quantum net-list | head -n -1 | tail -n +4 | awk '{print $2}' | xargs -L1 quantum net-delete || true
			[[ ! -z `quantum router-list` ]] && \
				quantum router-list | head -n -1 | tail -n +4 | awk '{print $2}' | xargs -L1 quantum router-delete || true
			exit
			;;
		t)
			TEMPLATE=$OPTARG
			;;
	esac
done

shift $((OPTIND-1))
VM=$1

#
# create external network - only by admin
#
if [ "$OS_USERNAME" = 'admin' ]; then
	EXTNET_ID=$(quantum net-list -- --tenant_id=$TENANT_ID --router:external=True | awk "/ $EXTNET / { print \$2 }")
	if [ -z "$EXTNET_ID" ]; then
		EXTNET_ID=$(quantum net-create $EXTNET --tenant_id=$TENANT_ID --router:external=True | grep ' id ' | awk '{print $4}')
	fi

	# create external subnet
	EXTSUBNET_ID=$(quantum net-show $EXTNET_ID | awk "/ subnets / { print \$4 }")
	if [ $EXTSUBNET_ID = "|" ]; then
		EXTSUBNET_ID=$(quantum subnet-create $EXTNET_ID "${EXTSUBNET}" \
					   --tenant_id=$TENANT_ID --name=${EXTNET}_subnet \
					   --enable_dhcp=False | awk '/ id / {print $4}')
	fi
else
	EXTNET_ID=$(quantum net-list -- --router:external=True | awk "/ $EXTNET / { print \$2 }")
fi

#
# Setup default security group
#
if [ -z "$(nova secgroup-list-rules default)" ]; then
	nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
	nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
	nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
fi

#
# tenant internal network
#

# create private network
NET_ID=$(quantum net-list -- --tenant_id=$TENANT_ID --name=$PRINET | awk "/ $PRINET / { print \$2 }")
if [ -z "$NET_ID" ]; then
	echo -n 'create tenant private network: '
	NET_ID=$(quantum net-create $PRINET --tenant_id=$TENANT_ID | grep ' id ' | awk '{print $4}')
	echo "NET=$NET_ID"
fi

# create private subnet
SUBNET_ID=$(quantum net-show $NET_ID | awk "/ subnets / { print \$4 }")
if [ $SUBNET_ID = "|" ]; then
	echo -n "Create subnet for ${NET_ID}: "
	SUBNET_ID=$(quantum subnet-create $NET_ID "${PRISUBNET}" \
				--tenant_id=$TENANT_ID --name=${PRINET}_subnet \
				--dns_nameservers list=true ${DNS} | \
				awk '/ id / {print $4}')
	echo "SUBNET=$SUBNET_ID"
fi

# now internal network is working
# and connect to external network

# create router for connect to external network
ROUTER_NAME="router_${OS_USERNAME}_ext"
ROUTER_ID=$(quantum router-list -- --tenant_id=$TENANT_ID --name=$ROUTER_NAME | head -n -1 | tail -n +4 | awk '{print $2}')
if [ -z "$ROUTER_ID" ]; then
	echo -n 'Create router '
	ROUTER_ID=$(quantum router-create --tenant_id=$TENANT_ID $ROUTER_NAME | awk '/ id /{print $4}')
	echo "ROUTER=$ROUTER_ID"
fi

# connect router to subnet
ROUTER_PORT_ID=$(quantum port-list -- --tenant_id=${TENANT_ID} --fixed_ips subnet_id=${SUBNET_ID} --device_owner=network:router_interface | awk '/ip_address/{print $2}')
if [ -z "$ROUTER_PORT_ID" ]; then
	quantum router-interface-add $ROUTER_ID $SUBNET_ID
	quantum router-gateway-set $ROUTER_ID $EXTNET_ID
fi


#
# generate keypair
# default keypair name is ${OS_TENANT_NAME}_key
#
KEYNAME="${OS_TENANT_NAME}_key"
if ! nova keypair-list | grep " ${KEYNAME} " > /dev/null ; then
	nova keypair-add ${KEYNAME} > ${OS_TENANT_NAME}.key
	chmod 0600 ${OS_TENANT_NAME}.key
fi


#
# boot instance
#
if [ ! -z "$VM" ]; then
	TEMPLATE_ID=$(nova image-list | grep "$TEMPLATE" | head -n 1 | awk '{print $2}')
	echo "TEMPLATE=$TEMPLATE_ID"

	VM_ID=$(nova boot --image=$TEMPLATE_ID --flavor=1 --nic net-id=$NET_ID --key_name=${KEYNAME} $VM | awk '/ id /{print $4}')
	echo "VM=$VM_ID"

	# get port id for floatingip
	# wait for settle port
	while [ -z "$PORT_ID" ]; do
		PORT_ID=$(quantum port-list -- --device_id=$VM_ID | awk '/ip_address/{ print $2 }')
		sleep 1
	done
	echo "PORT=$PORT_ID"

	# create floating ip
	if [ $WITH_FLOATINGIP = "true" ]; then
		FLOATINGIP_ID=$(quantum floatingip-create $EXTNET | awk '/ id /{ print $4 }')
		echo "FLOATINGIP_ID=$FLOATINGIP_ID"

		# associate floating ip
		quantum floatingip-associate $FLOATINGIP_ID $PORT_ID
		quantum floatingip-show $FLOATINGIP_ID
	fi

	# create cinder volume and attach
	if [ $WITH_VOLUME = "true" ]; then
		VOLUME_ID=$(cinder create --display_name=${VM} 1 | awk '/ id /{print $4}')
		nova volume-attach ${VM_ID} ${VOLUME_ID} /dev/vdb
	fi

	nova show $VM_ID
fi


# vim: nu ai aw ts=4 sw=4
