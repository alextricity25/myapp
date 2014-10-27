#!/bin/bash

neutron net-create --provider:physical_network=extnet --provider:network_type=flat --shared --router:external=true external-net

neutron subnet-create external-net 192.168.100.0/24 --name external-subnet --gateway=192.168.100.1 --allocation-pool start=192.168.100.161,end=192.168.100.180


neutron net-create --provider:network_type=vxlan --provider:segmentation_id=10 --shared test-net
neutron subnet-create test-net 10.10.10.0/24 --name test-subnet --dns-nameservers list=true 8.8.8.8 4.2.2.2
