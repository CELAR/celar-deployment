#!/bin/bash

TOMCAT_VERSION=7.0.55
TOMCAT_DIR=/usr/share

yum -y update
yum install -y wget

#install java
yum -y install java-1.7.0-openjdk

#install cassandra
touch /etc/yum.repos.d/datastax.repo
echo "[datastax]" >> /etc/yum.repos.d/datastax.repo
echo "name= DataStax Repo for Apache Cassandra" >> /etc/yum.repos.d/datastax.repo
echo "baseurl=http://rpm.datastax.com/community" >> /etc/yum.repos.d/datastax.repo
echo "enabled=1" >> /etc/yum.repos.d/datastax.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/datastax.repo
yum -y install dsc20

#start cassandra
cassandra -f &

#download JCatascopia-Server and install it
#change location of rpm package to celar repo
wget http://109.231.122.22:8080/downloads/JCatascopia-Server-0.0.1-1.noarch.rpm
rpm -Uvh JCatascopia-Server-0.0.1-1.noarch.rpm 
/etc/init.d/JCatascopia-Server start

#download and instantiate tomcat
if [ ! -d /usr/share/apache-tomcat-$TOMCAT_VERSION ]; then
  wget http://mirror.olnevhost.net/pub/apache/tomcat/tomcat-7/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvfz apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_DIR/
  mv $TOMCAT_DIR/apache-tomcat-$TOMCAT_VERSION $TOMCAT_DIR/tomcat/
fi
$TOMCAT_DIR/tomcat/bin/startup.sh

#download and install JCatascopia-Web
#default location for tomcat based on rpm is /usr/share/tomcat/...
wget http://109.231.122.22:8080/downloads/JCatascopia-Web-0.0.1-1.noarch.rpm
rpm -Uvh JCatascopia-Web-0.0.1-1.noarch.rpm
