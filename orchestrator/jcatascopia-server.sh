#!/bin/bash

set -ex
set -o pipefail

TOMCAT_VERSION=7.0.55
TOMCAT_DIR=/usr/share

eval "sed -i 's/127.0.0.1.*localhost.*/127.0.0.1 localhost $HOSTNAME/g' /etc/hosts"

#may not be required but if its a clear VM lets update the base repos
yum update -y

#add celar repo
cat > /etc/yum.repos.d/celar1.repo <<EOF
[CELAR-snapshots]
name=CELAR-snapshots
baseurl=http://snf-175960.vm.okeanos.grnet.gr/nexus/content/repositories/snapshots
enabled=1
protect=0
gpgcheck=0
metadata_expire=30s
autorefresh=1
type=rpm-md
EOF

#add cassandra repo
cat > /etc/yum.repos.d/datastax.repo <<EOF
[datastax]
name= DataStax Repo for Apache Cassandra
baseurl=http://rpm.datastax.com/community
enabled=1
gpgcheck=0
EOF

#install wget
yum install -y wget

#install java
yum install -y java-1.7.0-openjdk

#install cassandra
yum -y install dsc20

#install JCatascopia-Server
yum install -y JCatascopia-Server

#download install and configure tomcat
if [ ! -d /usr/share/apache-tomcat-$TOMCAT_VERSION ]; then
  wget http://archive.apache.org/dist/tomcat/tomcat-7/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
  tar xvfz apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_DIR/
  mv $TOMCAT_DIR/apache-tomcat-$TOMCAT_VERSION $TOMCAT_DIR/tomcat/
fi

#install JCatascopia-Web
#default location for tomcat based on rpm is /usr/share/tomcat/...
yum install -y JCatascopia-Web

#start JCatascopia
/etc/init.d/JCatascopia-Server start

#you should also configure the firewall by opening ports 8080, 4245, 4242 and 4243
