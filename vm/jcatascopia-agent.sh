#!/bin/bash

SERVER_IP=localhost
JC_VERSION=0.0.1

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
if [ ! -d JCatascopia-Agent-$JC_VERSION-SNAPSHOT ]; then
  wget http://109.231.122.22:8080/downloads/JCatascopia-Agent-$JC_VERSION-SNAPSHOT.tar.gz
  tar xvfz JCatascopia-Agent-$JC_VERSION-SNAPSHOT.tar.gz
  eval "sed -i 's/server_ip=.*/server_ip=$SERVER_IP/g' JCatascopia-Agent-$JC_VERSION-SNAPSHOT/JCatascopiaAgentDir/resources/agent.properties"
  cd JCatascopia-Agent-$JC_VERSION-SNAPSHOT
  ./installer.sh
  cd ..
fi
/etc/init.d/JCatascopia-Agent restart
