This explains how to install chef server and chef client. 

**RUN SSH-key-gen 
**copy it to the node's you want chef-client on 
**install chef-client on nodes using: 
curl -L https//www.opscode.com/chef/install.sh | sudo bash
**Make the client.rb file on node:
sudo cat > /etc/chef/client.rb <<EOF
log_level	:info
log_location	STDOUT
chef_server_url	'https://chef.cook.book/' 
validation_client_name 'chef-validator' 
EOF
**Create an entry for the chef-server in the client's /etc/hosts file: 
echo  "<ip of chef server>	chef.cook.book" >> /etc/hosts
**make the .chef file and copy over the validation.pem file to the client node
scp root@chef.cook.book:/path/to/pemfiles/chef-validator.pem ~/.chef/validation.pem 

