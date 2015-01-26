#!/bin/bash 

#THis script will remove the nodes and clients from the file passed into the first 
#argument. 

if [ $# -lt 1 ];
	then 
	echo "./cleanChef IM_SURE"
	exit;
fi 


for i in `knife node list`;
do 

	knife client delete $i -y; 
	knife node delete $i -y; 
done; 

