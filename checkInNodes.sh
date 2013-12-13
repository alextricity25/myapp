#!/bin/bash

#This script installs chef-client to a group of remote machines. 
#The script takes in a file with a list of IP addresses 

echo "First..use ssh-keygen to generate a key, accepting all the defaults" 
echo "Then, copy the keys over to the servers using ssh-copy-id <user>@<deviceIP>"




for line in `cat $1`; do 
	echo "copying keys over..."; 
	ssh-copy-id root@$line;
	echo "Downloading makeClient.sh on the remote machines..";
	#ssh root@$line 'wget https://github.com/elextro/myapp/blob/master/makeClient.sh';
	echo $line; 
done;
