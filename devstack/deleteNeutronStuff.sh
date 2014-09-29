#!/bin/bash


if [ $# -ne 4 ];
  then
  echo "./deleteNeutronStuff.sh <router-name> <subnet-attached-to-router> <external-network> <private-network>"
  exit;
fi 

neutron router-gateway-clear $1
neutron router-interface-delete $1 $2
neutron router-delete $1

neutron net-delete $3
neutron net-delete $4
