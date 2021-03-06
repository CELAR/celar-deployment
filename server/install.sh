#!/bin/bash

set -exo pipefail

# The deployment assumes usage of SlipStream and its messaging via ss-get CLI.
# When deploying outside of SlipStream, uncomment and, if required, 
# update the following exports.  The environment vairables are used 
# in other scripts throughout the deployment process.
#export CELAR_REPO_KIND=releases
#export CELAR_REPO_BASEURL=http://snf-175960.vm.okeanos.grnet.gr/yum
#export GITHUB_BRANCH=master
#export GITHUB_PROJECTURL=https://raw.githubusercontent.com/CELAR/celar-deployment
#export SS_REPO_KIND=Releases
#export CONNECTORS="fco okeanos"

if [ -z "${GITHUB_BRANCH}" ]; then
   export GITHUB_BRANCH=$(ss-get github-branch)
fi 
if [ -z "${GITHUB_PROJECTURL}" ]; then
   export GITHUB_PROJECTURL=$(ss-get github-projecturl)
fi

GITHUB_BASEURL=${GITHUB_PROJECTURL}/${GITHUB_BRANCH}

yum install -y curl

SCRIPTS="install-base-deps.sh
server/celar-server.sh
server/slipstream.sh
server/slipstream-celar-patch.sh"

for SCRIPT in $SCRIPTS; do
    echo "::: Downloading and launching $SCRIPT"
    curl -k -O $GITHUB_BASEURL/$SCRIPT
    SCRIPT=$(basename $SCRIPT)
    chmod +x $SCRIPT
    ./$SCRIPT
done

# Temporary
service iptables stop
