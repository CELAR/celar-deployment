#!/usr/bin/env bash
#
# SlipStream 2.3 PROD installation recipe
#

# THIS SCRIPT CONTAINS A HACK see at the bottom

# Fail fast and fail hard.
set -exo pipefail

# Return first global IPv4 address.                                            
function _get_hostname() {                                                     
    ip addr | awk '/inet .*global/ { split($2, x, "/"); print x[1] }' | head -1
}                                                                              

### Parameters

SS_VERSION=2.3.6

# First "global" IPv4 address                                                  
SS_HOSTNAME=$(_get_hostname)

# Type of repository to lookup for SlipStream packages. 'Releases' will install
# stable releases, whereas 'Snapshots' will install unstable/testing packages.
if [ -z "${SS_REPO_KIND}" ]; then
    SS_REPO_KIND=$(ss-get ss-repo-kind)
fi

if [ -z "${CONNECTORS}" ]; then
    CONNECTORS=$(ss-get ss-connectors)
fi

ADD_CELAR_REPO=false
CELAR_REPO_KIND=releases
#CELAR_REPO_KIND=$(ss-get celar-repo-kind)

# Directory with static content to deploy SlipStream client and Cloud clients
SS_STATIC_CONT_DIR=/opt/slipstream/downloads

SLIPSTREAM_EXAMPLES=false

# libcloud
CLOUD_CLIENT_LIBCLOUD_VERSION=0.14.1

# EPEL repository
EPEL_VER=6-8

# Packages from PyPi for SlipStream Client
PYPI_PARAMIKO_VER=1.9.0
PYPI_SCPCLIENT_VER=0.4

### Advanced parameters
CONFIGURE_FIREWALL=true

SLIPSTREAM_SERVER_HOME=/opt/slipstream/server
SLIPSTREAM_SERVER_LOGS=$SLIPSTREAM_SERVER_HOME/logs

SLIPSTREAM_CONF=/etc/slipstream/slipstream.conf
SLIPSTREAM_CONF_CONNECTORS_DIR=/etc/slipstream/connectors

DEPS="unzip curl wget gnupg nc python-pip"
CLEAN_PKG_CACHE="yum clean all"

###############################################

alias cp='cp'

function isTrue() {
    if [ "x${1}" == "xtrue" ]; then
        return 0
    else
        return 1
    fi
}

function configure_firewall () {
    isTrue $CONFIGURE_FIREWALL || return 0

    cat > /etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
    service iptables restart
}

function _add_yum_repos () {
    # EPEL
    EPEL_PKG=epel-release-${EPEL_VER}.noarch
    rpm -Uvh --force http://mirror.switch.ch/ftp/mirror/epel/6/i386/${EPEL_PKG}.rpm

    # Nginx
	rpm -Uvh --force http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm

    # SlipStream
	rpm -Uvh --force http://yum.sixsq.com/slipstream/centos/6/slipstream-repos-1.0-1.noarch.rpm
	yum-config-manager --disable SlipStream-*
	yum-config-manager --enable SlipStream-${SS_REPO_KIND}
}

function disable_selinux() {
    echo 0 > /selinux/enforce
    sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux /etc/selinux/config
}

function prepare_node () {

	yum install -y yum-utils

    _add_yum_repos

    echo "Installing $DEPS ..."
    yum install -y --enablerepo=epel $DEPS

    configure_firewall

    # Schema based http proxy for Python urllib2
    cat > /etc/default/jetty <<EOF
export JETTY_HOME=$SLIPSTREAM_SERVER_HOME
export TMPDIR=$SLIPSTREAM_SERVER_HOME/tmp
EOF
    cat >> /etc/default/jetty <<EOF
export http_proxy=$http_proxy
export https_proxy=$https_proxy
export JETTY_HOME=$SLIPSTREAM_SERVER_HOME
EOF

   disable_selinux
}

function deploy_HSQLDB () {
    echo "Installing HSQLDB..."

    service hsqldb stop || true
    kill -9 $(cat /var/run/hsqldb.pid) || true
    rm -f /var/run/hsqldb.pid

    yum install -y slipstream-hsqldb-${SS_VERSION}

    echo "Starting HSQLDB..."
    service hsqldb start || true # false-positive failure
}

function deploy_SlipStreamServerDependencies () {
    deploy_HSQLDB
}

function deploy_SlipStreamClient () {

    # Required by SlipStream cloud clients CLI
    pip install -Iv apache-libcloud==${CLOUD_CLIENT_LIBCLOUD_VERSION}

    # Required by SlipStream ssh utils
    yum install -y gcc python-devel
    # python-crypto clashes with Crypto installed as dependency with paramiko
    yum remove -y python-crypto
    pip install -Iv paramiko==$PYPI_PARAMIKO_VER
    pip install -Iv scpclient==$PYPI_SCPCLIENT_VER

    # winrm
    pip install https://github.com/diyan/pywinrm/archive/a2e7ecf95cf44535e33b05e0c9541aeb76e23597.zip

    yum install -y --enablerepo=epel slipstream-client-${SS_VERSION}
}

function deploy_SlipStreamServer () {
    echo "Deploying SlipStream..."

    service slipstream stop || true

    yum install -y slipstream-server-${SS_VERSION}

    update_slipstream_configuration

    deploy_CloudConnectors

    chkconfig --add slipstream
    service slipstream start

    deploy_nginx_proxy

    load_slipstream_examples
}

function update_slipstream_configuration() {

    sed -i -e "/^[a-z]/ s/slipstream.sixsq.com/${SS_HOSTNAME}/" \
           -e "/^[a-z]/ s/example.com/${SS_HOSTNAME}/" \
           $SLIPSTREAM_CONF

    _update_or_add_config_property slipstream.update.clienturl \
        https://${SS_HOSTNAME}/downloads/slipstreamclient.tgz
    _update_or_add_config_property slipstream.update.clientbootstrapurl \
        https://${SS_HOSTNAME}/downloads/slipstream.bootstrap
    _update_or_add_config_property cloud.connector.library.libcloud.url \
        https://${SS_HOSTNAME}/downloads/libcloud.tgz
    _update_or_add_config_property slipstream.base.url https://${SS_HOSTNAME}/
    _update_or_add_config_property cloud.connector.orchestrator.publicsshkey /opt/slipstream/server/.ssh/id_rsa.pub
    _update_or_add_config_property cloud.connector.orchestrator.privatesshkey /opt/slipstream/server/.ssh/id_rsa

}

function _update_or_add_config_property() {
	PROPERTY=$1
	VALUE=$2
    SUBST_STR="$PROPERTY = $VALUE"
    grep -qP "^[ \t]*$PROPERTY" $SLIPSTREAM_CONF && \
        sed -i "s|$PROPERTY.*|$SUBST_STR|" $SLIPSTREAM_CONF || \
        echo $SUBST_STR >> $SLIPSTREAM_CONF
}

function deploy_nginx_proxy() {

    # Install nginx and the configuratoin file for SlipStream
    yum install -y slipstream-server-nginx-conf-${SS_VERSION}

    if [ ! -f /etc/nginx/ssl/server.crt ]; then
        setup_ssl;
    fi

    chkconfig --add nginx
    service nginx start
}

function setup_ssl() {
    # Create a directory for the certificate
    mkdir -p /etc/nginx/ssl

    # Moving to certificate directory
    pushd /etc/nginx/ssl/

    # Creating the server private key
    openssl genrsa -out server.key 2048

    cat > openssl.cfg <<EOF
[ req ]
distinguished_name     = req_distinguished_name
x509_extensions        = v3_ca
prompt                 = no

dirstring_type = nobmp

[ req_distinguished_name ]
C = EU
CN = ${SS_HOSTNAME}

[ v3_ca ]
basicConstraints = CA:false
nsCertType=server, email, objsign
keyUsage=critical, digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
EOF

    # Creating the Certificate Signing Request (CSR)
    openssl req -new -key server.key -out server.csr -config openssl.cfg

    # Signing the certificate using the former private key and CSR
    openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

    # Restoring to previous directory
    popd
}

function load_slipstream_examples() {
    isTrue $SLIPSTREAM_EXAMPLES || return 0

    sleep 5
    ss-module-upload -u ${SS_USERNAME} -p ${SS_PASSWORD} \
        --endpoint https://localhost /usr/share/doc/slipstream/*.xml
}

function _add_celar_repo() {
	isTrue $ADD_CELAR_REPO || return 0

	cat > /etc/yum.repos.d/celar.repo <<EOF
[CELAR-${CELAR_REPO_KIND}]
name=CELAR-${CELAR_REPO_KIND}
baseurl=http://snf-175960.vm.okeanos.grnet.gr/yum/${CELAR_REPO_KIND}
enabled=1
protect=0
gpgcheck=0
metadata_expire=30s
autorefresh=1
type=rpm-md
EOF
}

function _install_ss_connector_okeanos() {
	pip install kamaki
	yum -y install slipstream-connector-okeanos

	cat > ${SLIPSTREAM_CONF_CONNECTORS_DIR}/okeanos.conf << EOF
# ~Okeanos
cloud.connector.class = Okeanos:okeanos
Okeanos.service.type = compute
Okeanos.service.name = cyclades_compute
Okeanos.orchestrator.imageid = fe31fced-a3cf-49c6-b43b-f58f5235ba45
Okeanos.orchestrator.instance.type = C2R2048D10ext_vlmc
Okeanos.endpoint = https://accounts.okeanos.grnet.gr/identity/v2.0
Okeanos.update.clienturl = https://${SS_HOSTNAME}/downloads/okeanoslibs.tar.gz
Okeanos.max.iaas.workers = 20
Okeanos.service.region = default
Okeanos.quota.vm =
EOF

}

function _install_ss_connector_fco() {

	yum -y install slipstream-connector-fco

	cat > ${SLIPSTREAM_CONF_CONNECTORS_DIR}/flexiant.conf << EOF
# Flexiant (Orchestrator size is missing).
cloud.connector.class = Flexiant:flexiant
Flexiant.endpoint = https://cp.sd1.flexiant.net:4442/
Flexiant.orchestrator.imageid = 81aef2d3-0291-38ef-b53a-22fcd5418e60
Flexiant.update.clienturl = https://${SS_HOSTNAME}/downloads/flexiantclient.tgz
Flexiant.max.iaas.workers = 20
Flexiant.quota.vm =
EOF

}

function deploy_CloudConnectors() {
	_add_celar_repo
	for connector in ${CONNECTORS}; do
		_install_ss_connector_${connector}
	done
}

function cleanup () {
    $CLEAN_PKG_CACHE
}

prepare_node
deploy_SlipStreamServerDependencies
deploy_SlipStreamClient
deploy_SlipStreamServer
cleanup

echo "::: SlipStream installed."

# HACKs go here
touch /opt/slipstream/connectors/bin/slipstream.client.conf

exit 0
