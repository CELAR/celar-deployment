#!/bin/bash

TOMCAT_VERSION=7.0.56
TOMCAT_DIR=/usr/share

yum install -y wget

#install java
yum install -y java-1.7.0-openjdk

#download and instantiate tomcat
if [ ! -d /usr/share/apache-tomcat-$TOMCAT_VERSION ]; then
  wget http://archive.apache.org/dist/tomcat/tomcat-7/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvfz apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_DIR/
  mv $TOMCAT_DIR/apache-tomcat-$TOMCAT_VERSION $TOMCAT_DIR/tomcat/
fi
$TOMCAT_DIR/tomcat/bin/startup.sh


# Change tomcat listening port
sed -i 's|port="8080"|port="8880"|g' $TOMCAT_DIR/tomcat/conf/server.xml

#Open tomcat port
iptables -A INPUT -m state --state NEW,ESTABLISHED -m tcp -p tcp --dport 8880 -j ACCEPT

#default location for tomcat based on rpm is /usr/share/tomcat/...
#download cloud-is-core and install it
yum install -y cloud-is-core


#download and install cloud-is-web
yum install -y cloud-is-web