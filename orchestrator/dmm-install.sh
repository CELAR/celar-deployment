#!/bin/bash

#added mysql support for mela, to reduce RAM usage
#!/bin/bash
yum -q -y install mysql mysql-server

chkconfig mysqld on
service mysqld start

#wait for mysql to start, to initialize it
until pids=$(pidof mysqld)
do   
    sleep 5
done

#add mela user and database
mysql -uroot -e <<EOSQL "UPDATE mysql.user SET Password=PASSWORD('c3lar') WHERE User='root'; CREATE USER 'mela'@'localhost' IDENTIFIED BY 'mela'; GRANT ALL PRIVILEGES ON * . * TO 'mela'@'localhost'; FLUSH PRIVILEGES; 
create database mela;
use mela;

create table MonitoringSeq (ID VARCHAR(200) PRIMARY KEY);
create table Timestamp (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200), timestamp BIGINT, serviceStructure LONGTEXT, FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID) );
create table RawCollectedData (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200), timestampID int, metricName VARCHAR(100), metricUnit VARCHAR(100), metrictype VARCHAR(20), value VARCHAR(50),  monitoredElementID VARCHAR (50), monitoredElementLevel VARCHAR (50), FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID), FOREIGN KEY (timestampID) REFERENCES Timestamp(ID));
create table Configuration (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200),configuration LONGTEXT, FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID));
create table AggregatedData (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200), timestampID int, data  LONGBLOB, FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID), FOREIGN KEY (timestampID) REFERENCES Timestamp(ID) );
create table ElasticitySpace (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200),  startTimestampID int, endTimestampID int, elasticitySpace  LONGBLOB, FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID), FOREIGN KEY (startTimestampID) REFERENCES Timestamp(ID), FOREIGN KEY (endTimestampID) REFERENCES Timestamp(ID) );
create table ElasticityPathway (monSeqID VARCHAR(200) PRIMARY KEY, timestampID int, elasticityPathway  LONGBLOB, FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID), FOREIGN KEY (timestampID) REFERENCES Timestamp(ID) );
create table ELASTICITYDEPENDENCY (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200), startTimestampID int, endTimestampID int, elasticityDependency LONGTEXT, FOREIGN KEY (monSeqID) REFERENCES MonitoringSeq(ID), FOREIGN KEY (startTimestampID) REFERENCES Timestamp(ID), FOREIGN KEY (endTimestampID) REFERENCES Timestamp(ID) );
create table Events (ID int AUTO_INCREMENT PRIMARY KEY, monSeqID VARCHAR(200), event VARCHAR(200), flag VARCHAR(10));
"
EOSQL

#inchreasing max_allowed_packet to allow elasticity space to be stored
eval "sed -i 's#\[mysqld\].*#\[mysqld\] \n max_allowed_packet=500MB#' /etc/my.cnf"

service mysqld restart

echo "Done configuring mysql"

echo installing mela-data-service
yum install -y mela-data-service
 
echo installing mela-analysis-service
yum install -y mela-analysis-service

echo installing celar-decision-making
yum install -y celar-decision-making

