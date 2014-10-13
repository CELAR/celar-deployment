#!/bin/bash

echo 127.0.0.1 $(hostname) >> /etc/hosts

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
orchestrator/slipstream-orch-deps.sh
orchestrator/jcatascopia-server.sh
orchestrator/dmm-install.sh
orchestrator/celar-orch.sh
orchestrator/add-iptables-rules.sh"

for SCRIPT in $SCRIPTS; do
    echo "::: Downloading and launching $SCRIPT"
    curl -k -O $GITHUB_BASEURL/$SCRIPT
	SCRIPT=$(basename $SCRIPT)
    chmod +x $SCRIPT
    ./$SCRIPT
done
