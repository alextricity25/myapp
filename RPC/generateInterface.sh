#!/bin/bash

#Change the IP address to match yours

TUNNEL_IP=2

if [ $# -eq 0 ]
then
	echo "./generateInterfaces <iplist.txt>"
	exit
fi

if [ ! -e "$1" ]
then
	echo "File does not exist, enter the path of the file with the list of IPs"
	exit
fi

for i in `cat $1`; do

cat << EOF > /tmp/global.$i.cfg

auto eth0
iface eth0 inet manual

auto eth1
iface eth1 inet manual 

auto br-mgmt
iface br-mgmt inet static
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	bridge_ports eth0
	address $i
	netmask 255.255.0.0
	gateway <your-gateway>
	dns-nameservers 8.8.8.8 4.2.2.2

auto br-vlan
iface br-vlan inet manual 
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	bridge_ports eth1
	address 172.16.0.$TUNNEL_IP
	netmask 255.255.255.0


auto br-vxlan 
iface br-vxlan inet manual 
	bridge_stp off
	bridge_waitport 0
	bridge_fd 0
	bridge_ports none


EOF

TUNNEL_IP=$(( TUNNEL_IP += 1 ))
#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
done; 




