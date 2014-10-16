#!/bin/bash

set -ex

function install_pkgs() {
	cmd=`which yum 2>/dev/null`
	if [ -z "$cmd" ] ; then
		cmd=`which apt-get`
	fi
	$cmd -y install $@
}

install_pkgs python python-pip gcc python-devel

PYPI_PARAMIKO_VER=1.9.0
PYPI_SCPCLIENT_VER=0.4
# python-crypto clashes with Crypto installed as dependency with paramiko
yum remove -y python-crypto || true
pip install -Iv paramiko==$PYPI_PARAMIKO_VER
pip install -Iv scpclient==$PYPI_SCPCLIENT_VER
