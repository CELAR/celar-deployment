#!/bin/bash

set -ex

function install_pkgs() {
	cmd=`which yum 2>/dev/null || true`
	if [ -z "$cmd" ] ; then
		cmd=`which apt-get`
	fi
	sudo $cmd -y install $@
}

install_pkgs python python-pip gcc
