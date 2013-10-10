#!/bin/bash

if [ $# -ne 2 ]; 
	then 
	echo "./makeClient.sh <hostname> <IP-of-chef-server>"; 
	exit; 
fi

echo "Hostname is: $1"; 
echo "IP of chef server is: $2"; 

curl -L https://www.opscode.com/chef/install.sh | sudo bash 
mkdir -p /etc/chef 
if [ -e /etc/chef/client.rb ]; 
	then 
		rm -rf /etc/chef/client.rb
fi 
cat > /etc/chef/client.rb <<endmsg
log_level	:info 
log_location	STDOUT	
chef_server_url 'https://$1/' 
validation_client_name 'chef-validator'
endmsg

echo "$2	$1" >> /etc/hosts; 
echo "Please copy the chef-validator.pem file from the chef server using the command:"; 
echo "scp root@$1:/etc/chef-server/chef-validator.pem /etc/chef/validation.pem"; 

