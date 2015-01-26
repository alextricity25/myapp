#!/bin/bash

if [ $# -lt 2 ]
then
	echo "./populateComputeHosts <last-octect-of-ip-of-first-compute> <num-of-compute-nodes>"
	exit
fi

IP_ADDRS=$1
for i in $(eval echo {1..$2}); do
	echo "  compute$i:"
	echo "    ip:10.241.51.$IP_ADDRS"
	IP_ADDRS=$(( $IP_ADDRS + 1 ))
done; 
