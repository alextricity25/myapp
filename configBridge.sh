#!/bin/bash 


#This script takes in the name a file which contains a list of ipadress to configure. 


if [ $# -lt 1 ]; 
	then 
	echo "./configBridge <file_name>"
	echo "Please make sure you have the ssh-key copied to the remote machine"
	exit; 
fi 


for ipaddr in `cat $1` 
do
cat > /tmp/interfaces <<endmsg
# This file describes the network interfaces available on your system 
# and how to activate them. For more information, see interfaces(5). 

#The loopback network interface 
auto lo
iface lo inet loopback

# The primary network interface 
auto eth0
iface eth0 inet manual 
	up ip l s $IFACE up
	down ip l s $IFACE down 

iface br-eth0 inet static 
	address $ipaddr
	netmask 255.255.255.0
	gateway 10.127.83.1
	nameserver 8.8.8.8
endmsg

echo "-------------Copying interface file to remote machine $ipaddr" 
scp /tmp/interfaces root@$ipaddr:/etc/network/interfaces
echo "-------------Flushing eth0 for..$ipaddr, restarting networking, bringing up bridge."
ssh root@$ipaddr "ip addr flush dev eth0;/etc/init.d/networking restart;ifup br-eth0; ovs-vsctl add-port br-eth0 eth0"
echo "------------------------------------------------" 
echo "Now try sshing into the machine and pingining 8.8.8.8"

done; 
