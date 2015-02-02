#!/bin/bash

#Change the IP address to match yours

TUNNEL_IP=101
CONTAINER_IP=102 
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

auto br-mgmt
iface br-mgmt inet static
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Notice the bridge port is the vlan tagged interface
    bridge_ports em1
    address $i
    netmask 255.255.255.0
    gateway 10.127.83.1
    up ip addr add 172.16.236.$CONTAINER_IP/22 dev br-mgmt label br-mgmt:0

auto br-vxlan
iface br-vxlan inet manual
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports none

auto br-vlan
iface br-vlan inet static
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Notice this bridge port is an Untagged host interface
    bridge_ports em2
    address 172.16.240.$TUNNEL_IP
    netmask 255.255.252.0


EOF

TUNNEL_IP=$(( TUNNEL_IP += 1 ))
CONTAINER_IP=$(( CONTAINER_IP += 2 ))
#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
scp /tmp/global.$i.cfg root@$i:/etc/network/interfaces.d/

done; 




