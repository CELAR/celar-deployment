#!/bin/bash

set -exo pipefail

GITHUB_BRABCH=$(ss-get github-branch)
GITHUB_PROJECTURL=$(ss-get github-projecturl)

GITHUB_BASEURL=${GITHUB_PROJECTURL}/${GITHUB_BRABCH}

yum install -y curl

SCRIPTS="install-base-deps.sh
orchestrator/slipstream-orch-deps.sh
orchestrator/dmm-install.sh
orchestrator/jcatascopia-server.sh"

for SCRIPT in $SCRIPTS; do
    echo "::: Downloading and launching $SCRIPT"
    curl -k -O $GITHUB_BASEURL/$SCRIPT
	SCRIPT=$(basename $SCRIPT)
    chmod +x $SCRIPT
    ./$SCRIPT
done
