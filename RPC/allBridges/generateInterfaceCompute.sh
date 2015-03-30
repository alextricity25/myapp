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
    #Create veth pair, don't bomb if already exists
    pre-up ip link add br-vxlan-veth type veth peer name em15 || true
    pre-up ip link add br-storage-veth type veth peer name em16 || true
    # Set both ends UP
    pre-up ip link set br-vxlan-veth up
    pre-up ip link set em15 up
    pre-up ip link set br-storage-veth up
    pre-up ip link set em16 up
    #Set bridge UP/DOWN
    up ip link set \$IFACE up
    down ip link set \$IFACE down
    #delete veth pair on DOWN
    post-down ip link del br-vxlan-veth || true
    post-down ip link del br-storage-veth || true
    #Set Bridge options, also configure a second "fake" network
    #as a sub-interface for the containers. This network does not
    #have a gateway.
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports em1 br-vxlan-veth br-storage-veth
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
    bridge_ports em15

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
    bridge_ports em16

EOF

TUNNEL_IP=$(( TUNNEL_IP += 1 ))
CONTAINER_IP=$(( CONTAINER_IP += 1 ))
#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
scp /tmp/global.$i.cfg root@$i:/etc/network/interfaces.d/

done; 
