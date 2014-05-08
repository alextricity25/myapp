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

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet manual
        up ip link set \$IFACE up 
        down ip link set \$IFACE down 

iface br-eth1 inet manual
endmsg

echo "-------------Copying interface file to remote machine $ipaddr" 
scp /tmp/interfaces root@$ipaddr:/etc/network/interfaces
echo "-------------Flushing eth1 for..$ipaddr, restarting networking, bringing up bridge."
ssh root@$ipaddr "ip addr flush dev eth1;/etc/init.d/networking restart;ifup br-eth1; ovs-vsctl add-port br-eth1 eth1"
echo "------------------------------------------------" 
echo "Now try sshing into the machine and pingining 8.8.8.8"

done;
