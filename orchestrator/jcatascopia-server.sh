#!/bin/bash

TOMCAT_VERSION=7.0.55
TOMCAT_DIR=/usr/share

eval "sed -i 's/127.0.0.1.*localhost.*/127.0.0.1 localhost $HOSTNAME/g' /etc/hosts"

yum install -y wget

#install java
yum install -y java-1.7.0-openjdk

#install cassandra
cat > /etc/yum.repos.d/datastax.repo <<EOF
[datastax]
name= DataStax Repo for Apache Cassandra
baseurl=http://rpm.datastax.com/community
enabled=1
gpgcheck=0
EOF
yum -y install dsc20

#start cassandra
cassandra -f &

#download JCatascopia-Server and install it
yum install -y JCatascopia-Server
/etc/init.d/JCatascopia-Server start

#download and instantiate tomcat
if [ ! -d /usr/share/apache-tomcat-$TOMCAT_VERSION ]; then
  wget http://archive.apache.org/dist/tomcat/tomcat-7/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvfz apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_DIR/
  mv $TOMCAT_DIR/apache-tomcat-$TOMCAT_VERSION $TOMCAT_DIR/tomcat/
fi
$TOMCAT_DIR/tomcat/bin/startup.sh

#download and install JCatascopia-Web
#default location for tomcat based on rpm is /usr/share/tomcat/...
yum install -y JCatascopia-Web
