#!/bin/bash

#Change the IP address to match yours

for i in {161..174}; do
cat << EOF > /tmp/host-network.$i.cfg
auto eth0
iface eth0 inet manual

auto eth0.101
iface eth0.101 inet static
	address 10.0.0.$i
	netmask 255.255.255.0
	vlan-raw-device eth0
EOF

#Management bridge
cat << EOF > /tmp/mgmt.$i.cfg

auto eth0.102
iface eth0.102 inet manual 
	vlan-raw-device eth0

auto br-mgmt
auto br-mgmt inet static
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	# Bridge port references tagged interface
	bridge_ports eth0.102
	address 10.1.0.$i
	netmask 255.255.255.0
	gateway 10.1.0.1
	dns-nameservers 8.8.8.8 4.2.2.2
EOF

#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
done; 




