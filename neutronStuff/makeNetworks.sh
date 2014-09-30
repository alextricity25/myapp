#!/bin/bash

#$1 = start of Ip allocation range for external subnet
#$2 = end of ip allocation range for external subnet


#This script will create a neutron physical provider network for the 192.168.100.0/24 network in the SAT6 lab. It will also create a tenant network configured to use vxlan tunnels. 

echo "192.168.100.$1"

neutron net-create --provider:physical_network=extnet --provider:network_type=flat --shared --router:external=true external-net

neutron subnet-create external-net 192.168.100.0/24 --name external-subnet --gateway=192.168.100.1 --allocation-pool start=192.168.100.$1,end=192.168.100.$2


neutron net-create --provider:network_type=vxlan --provider:segmentation_id=10 --shared testnet1
neutron subnet-create testnet1 10.10.10.0/24 --name testsubnet1 --dns-nameservers list=true 8.8.8.8 4.2.2.2
neutron router-create neutron-router
neutron router-gateway-set neutron-router external-net
neutron router-interface-add neutron-router testsubnet1
