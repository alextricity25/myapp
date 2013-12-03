#!/bin/bash 

#This script takes in a variable number of serial codes and deletes their respective razor active model. It must be ran on a machine with razor. 


razorPath=$(which razor)


echo "Checking to see if razor is installed.." 
if [ -a $razorPath ]
    then 
        echo "Razor is indeed installed..."
    else 
        echo "Razor is not installed. Razor must be installed to use this script." 
        exit
fi 

declare -A activeModels

#building hash of active models
activeModelNodeUUID=( `razor active_model | grep -Ev 'Active|Label' | awk '{print $3;}'` ) 
activeModelUUID=( $(razor active_model | grep -Ev 'Acitve|Label' | awk '{print $6;}') )
   
echo "Parsing the serial codes.." 

for serialCode in "$@"
do
    if [ ${#serialCode} -lt 4 ] 
    then
        echo "You must enter at least 4 letters/numbers of the serial code"
        exit
    fi
    echo "Searching for an active model with the serial code: $serialCode"
    for ((i=0;i<=${#activeModelNodeUUID[@]}-1;i++)); do 
       isActiveModel=`razor node ${activeModelNodeUUID[i]} -f attrib | grep -oE "$serialCode"`
       #echo "$isActiveModel"
       if [ -n "$isActiveModel" ]
       then 
           echo "Found active model with serial number: $isActiveModel"
           echo "${activeModelUUID[i]}";
           echo "Removing from active model list..."
           $razorPath active_model remove "${activeModelUUID[i]}"
       fi
    done

done; 


