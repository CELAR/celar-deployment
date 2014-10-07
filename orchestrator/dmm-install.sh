#!/bin/bash
#due to version conflicts and bad naming, yum does not always load the correct rpm.
function getLatestVersion(){
yum --showduplicates list $1 | grep 1.0- >> /tmp/$1-rpm
while read i; do lastline=$i ; done < /tmp/$1-rpm
count=0;
for i in $lastline; do
   if [  $count -eq 1 ]; then
        version=$i
   fi
   let "count+=1"
done;
 echo $version
}


dmversion=$(getLatestVersion mela-data-service)
echo installing mela-data-service-$dmversion
yum install mela-data-service-$dmversion


dmversion=$(getLatestVersion mela-analysis-service)
echo installing mela-analysis-service-$dmversion
yum install mela-analysis-service-$dmversion


dmversion=$(getLatestVersion celar-decision-making)
echo installing celar-decision-making-$dmversion
yum install celar-decision-making-$dmversion


#yum -y install mela-data-service --skip-broken
#yum -y install mela-analysis-service --skip-broken
#yum -y install celar-decision-making --skip-broken
