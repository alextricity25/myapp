#!/bin/bash

#Change the IP address to match yours

TUNNEL_IP=101

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

# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

source /etc/network/interfaces.d/*.cfg

EOF

TUNNEL_IP=$(( TUNNEL_IP += 1 ))
#scp /tmp/host-network.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
#scp /tmp/mgmt.$i.cfg root@10.0.0.$i:/etc/network/interfaces.d/
scp /tmp/global.$i.cfg root@$i:/etc/network/interfaces

done; 




