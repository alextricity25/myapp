#!/bin/bash

#Check number of arguments for correct usage 
if [ $# -ne 3 ]; 
	then 
	echo "./checkInNodes.sh <iplist.txt> <chef-server-ip> <chef-server-hostname>"
	exit; 
fi 

#This script installs chef-client to a group of remote machines. 
#The script takes in a file with a list of IP addresses 

echo "First..use ssh-keygen to generate a key, accepting all the defaults" 
echo "Then, copy the keys over to the servers using ssh-copy-id <user>@<deviceIP>"




for line in `cat $1`; do 
	echo "copying keys over..."; 
	ssh-copy-id root@$line;
	echo "-----------Removing any chef files that might have been generated by razor.."
	ssh root@$line 'rm -rf /etc/chef/*'
	echo "-----------Removing any old makeClient* files"; 
	ssh root@$line 'rm -rf /root/makeClient*'
	echo "-----------Downloading makeClient.sh on $line";
	ssh root@$line 'wget https://raw.github.com/elextro/myapp/master/makeClient.sh'
	ssh root@$line 'chmod ugo+x /root/makeClient.sh'
	echo "-----------installing chef on $line" 
	ssh root@$line "/root/makeClient.sh $3 $2";
	echo "-----------Copying over validation file to $line"
	scp /etc/chef-server/chef-validator.pem root@$line:/etc/chef/validation.pem;
	echo "-----------Checking in $line with chef-server"
	ssh root@$line "chef-client"
	echo $line; 
done;
