#!/bin/bash

set -ex

CELAR_REPO_KIND=$(ss-get celar-repo-kind)
CELAR_REPO_BASEURL=$(ss-get celar-repo-baseurl)

function add_celar_repo() {
    cat > /etc/yum.repos.d/celar.repo <<EOF
[CELAR-${CELAR_REPO_KIND}]
name=CELAR-${CELAR_REPO_KIND}
baseurl=${CELAR_REPO_BASEURL}/${CELAR_REPO_KIND}
enabled=1
protect=0
gpgcheck=0
metadata_expire=30s
autorefresh=1
type=rpm-md
EOF
}

function install_helpers() {
	yum -y install curl
}

add_celar_repo
install_helpers
