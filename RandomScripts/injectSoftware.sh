#!/bin/bash 

#This program injects java and vdbench to a 64 bit machine

if [ $# -ne 4 ]; 
then 
	echo "./injectSoftware.sh <ip-addr> <keyfile> <vdbenchTar> <javaDir>"; 
	exit; 
fi 

TARGET=$1; 
KEYFILE=$2; 
VDTAR=$3; 
JAVADIR=$4; 

ssh -i $KEYFILE root@$TARGET "mkdir -p /root/vdbench"
scp -i $KEYFILE $VDTAR root@$TARGET:/root/vdbench
ssh -i $KEYFILE root@$TARGET "mkdir -p /usr/local/java" 
scp -i $KEYFILE $JAVADIR/* root@$TARGET:/usr/local/java/
ssh -i $KEYFILE root@$TARGET "tar -C /usr/local/java -xvzf /usr/local/java/jdk-7u40-linux-i586.gz"
ssh -i $KEYFILE root@$TARGET "tar -C /usr/local/java -xvzf /usr/local/java/jre-7u40-linux-i586.gz" 
ssh -i $KEYFILE root@$TARGET "echo JAVA_HOME=/usr/local/java/jdk1.7.0_40 >> /etc/profile"
ssh -i $KEYFILE root@$TARGET "echo PATH=$PATH:$HOME/bin:$JAVA_HOME/bin >> /etc/profile"
ssh -i $KEYFILE root@$TARGET "echo JRE_HOME=/usr/local/java/jre1.7.0_40 >> /etc/profile "
ssh -i $KEYFILE root@$TARGET "echo PATH=$PATH:$HOME/bin:$JRE_HOME/bin >> /etc/profile"
ssh -i $KEYFILE root@$TARGET "echo "export JAVA_HOME" >> /etc/profile"
ssh -i $KEYFILE root@$TARGET "echo "export JRE_HOME" >> /etc/profile" 
ssh -i $KEYFILE root@$TARGET "echo "export PATH" >> /etc/profile" 

ssh -i $KEYFILE root@$TARGET "update-alternatives --install '/usr/bin/java' 'java' '/usr/local/java/jre1.7.0_40/bin/java' 1"
ssh -i $KEYFILE root@$TARGET "update-alternatives --install '/usr/bin/javac' 'javac' '/usr/local/java/jdk1.7.0_40/bin/javac' 1"
ssh -i $KEYFILE root@$TARGET "update-alternatives --install '/usr/bin/javaws' 'javaws' '/usr/local/java/jre1.7.0_40/bin/javaws' 1" 

ssh -i $KEYFILE root@$TARGET "update-alternatives --set java /usr/local/java/jre1.7.0_40/bin/java"
ssh -i $KEYFILE root@$TARGET "update-alternatives --set javac /usr/local/java/jdk1.7.0_40/bin/javac"
ssh -i $KEYFILE root@$TARGET "update-alternatives --set javaws /usr/local/java/jre1.7.0_40/bin/javaws" 

ssh -i $KEYFILE root@$TARGET ". /etc/profile" 

ssh -i $KEYFILE root@$TARGET "apt-get install libc6-i386 -y"
