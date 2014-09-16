#!/bin/bash

#Change the IP address to match yours

for i in {161..174}; do

cat << EOF > /tmp/global.$i.cfg
auto eth0
iface em1 inet manual


iface eth0.111 inet manual 
	vlan-raw-device eth0
	
iface eth0.222 inet manual
	vlan-raw-device eth0
	
auto br-mgmt
iface br-mgmt inet static
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	bridge_ports eth0
	address 10.241.1.$i
	netmask 255.255.0.0
	gateway 10.241.253.253
	dns-nameservers 8.8.8.8 4.2.2.2
	
auto br-vlan
iface br-vlan inet manual
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	bridge_ports eth0.111
	
auto br-vxlan
iface br-vxlan inet manual
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	bridge_ports eth0.222

EOF

#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
done; 




