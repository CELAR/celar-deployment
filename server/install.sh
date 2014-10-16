#!/bin/bash

set -exo pipefail

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
