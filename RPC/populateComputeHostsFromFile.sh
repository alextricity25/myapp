#!/bin/bash

if [ $# != 1 ]
then
	echo "./populateComputeHosts <full path to file>"
	exit
fi

HOSTS=`cat $1`
for HOST in $HOSTS; do
	echo "  compute$HOST:"
	echo "    ip: $HOST"
done; 


