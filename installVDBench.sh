#!/bin/bash 

#Usage information 
if [ $# > 1 ]; 
then 
	echo "Usage: ./installVDBench" 
fi 


echo "Installing java..." 
#installing java
add-apt-repository ppa:webupd8team/java -y 
apt-get update -y 
apt-get install oracle-jdk7-installer -y 
java -version 

# Installing VDBench 
mkdir ./vdbench 
wget http://sourceforge.net/projects/vdbench/files/vdbench502.tar/download ./vdbench
tar -xvf ./vdbench/download -C ./vdbench



