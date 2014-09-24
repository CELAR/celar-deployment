#!/bin/bash

#must be set at runtime to JCatascopia-Server IP, default set to localhost
SERVER_IP=localhost

CELAR_REPO=http://snf-175960.vm.okeanos.grnet.gr
JC_VERSION=LATEST
JC_ARTIFACT=JCatascopia-Agent
JC_GROUP=eu.celarcloud.cloud-ms
JC_TYPE=tar.gz

DISTRO=$(eval cat /etc/*release)
if [[ "$DISTRO" == *Ubuntu* ]]; then
        apt-get update -y
        #download and install java
        apt-get install -y openjdk-7-jre-headless
fi

if [[ "$DISTRO" == *CentOS* ]]; then
        yum -y update
        yum install -y wget
        #download and install java
        yum -y install java-1.7.0-openjdk
fi

#download,install and start jcatascopia agent...
URL="$CELAR_REPO/nexus/service/local/artifact/maven/redirect?r=snapshots&g=$JC_GROUP&a=$JC_ARTIFACT&v=$JC_VERSION&p=$JC_TYPE"
wget -O JCatascopia-Agent.tar.gz $URL
tar xvfz JCatascopia-Agent.tar.gz
eval "sed -i 's/server_ip=.*/server_ip=$SERVER_IP/g' JCatascopia-Agent-*/JCatascopiaAgentDir/resources/agent.properties"
cd JCatascopia-Agent-*
./installer.sh
cd ..
/etc/init.d/JCatascopia-Agent restart
