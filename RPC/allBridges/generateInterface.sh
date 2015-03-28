#!/bin/bash

#Change the IP address to match yours

TUNNEL_IP=107
CONTAINER_IP=107
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

auto em1
iface em1 inet manual

auto br-mgmt
iface br-mgmt inet static
    pre-up ip link add vxlan-veth0 type veth peer name vxlan-veth1
    pre-up ip link add storage-veth0 type veth peer name storage-veth1
    pre-down ip link del dev vxlan-veth0
    pre-down ip link del dev storage-veth0
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports em1 vxlan-veth0 storage-veth0
    address $i
    netmask 255.255.255.0
    gateway 10.127.83.1
    up ip addr add 172.16.236.$CONTAINER_IP/24 dev \$IFACE label \$IFACE:0

auto br-vxlan
iface br-vxlan inet static
    address 172.16.237.$TUNNEL_IP
    netmask 255.255.255.0
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports vxlan-veth1

auto br-vlan
iface br-vlan inet manual
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Notice this bridge port is an Untagged host interface
    bridge_ports em2

auto br-storage
iface br-storage inet static
    address 172.16.238.$TUNNEL_IP
    netmask 255.255.255.0
    bridge_stop off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports storage-veth1

EOF

TUNNEL_IP=$(( TUNNEL_IP += 1 ))
CONTAINER_IP=$(( CONTAINER_IP += 1 ))
#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
scp /tmp/global.$i.cfg root@$i:/etc/network/interfaces.d/

done; 
