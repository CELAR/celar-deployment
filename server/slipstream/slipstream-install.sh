#!/usr/bin/env bash
#
# SlipStream 2.x PROD installation recipe
#

# Fail fast and fail hard.
set -eox pipefail

### BEGIN SLIPSTREAM UTILITIES ------8<-----------------8<-----------------8<--
function ss-display (){
    echo $@
}

function ss-envvar () {
    # Transforming variable name to uppercase
    # and replacing dash (-), period (.) and semi-colon (:) to underscore (_)
    echo __$1 | tr "[:lower:]" "[:upper:]" | tr '-' '_' | tr '.' '_' | tr ':' '_'
}

function ss-set (){
    # Log the variable and associated value to a file
    echo "$(date -R) $1=$2" >> /var/log/slipstream.log
    # Define an ad-hoc envvar in case it's reused via ss-get
    local var=`ss-envvar $1`
    unset $var
    declare $var=$2
}

function ss-get (){
    # We're using the last parametaer as variable name since ss-get
    # can be used with options, like timeout (e.g. ss-get --timeout 2700 hostname)
    local var=`ss-envvar ${!#}`
    # Returning variable value
    echo ${!var}
}


# Settings
__HOSTNAME=$(/sbin/ifconfig eth0 | grep -P "inet add?r" | awk -F: '{print $2}' | awk '{print $1}')
__REPO_KIND='snapshots'
__CELAR_REPO_KIND='snapshots'
__SLIPSTREAM_USERNAME='super'
__SLIPSTREAM_PASSWORD='supeRsupeR'
__SLIPSTREAM_SIXSQ_USERNAME='sixsq'
__SLIPSTREAM_SIXSQ_PASSWORD='siXsQsiXsQ'
### END SLIPSTREAM UTILITIES ------8<-----------------8<-----------------8<----

### Parameters
SS_HOSTNAME=$(ss-get hostname)

# Type of repository to lookup for SlipStream packages. 'releases' will install
# stable releases, whereas 'snapshots' will install unstable/testing packages.
REPO_KIND=$(ss-get repo-kind)

CELAR_REPO_KIND=$(ss-get celar-repo-kind)
CONNECTORS="fco okeanos"

# Directory with static content to deploy SlipStream client and Cloud clients
SS_STATIC_CONT_DIR=/opt/slipstream/downloads

NGINX_PROXY=true
SLIPSTREAM_EXAMPLES=false

# libcloud
CLOUD_CLIENT_LIBCLOUD_VERSION=0.14.1

# EPEL repository
EPEL_VER=6-8

# Packages from PyPi for SlipStream Client
PYPI_PARAMIKO_VER=1.9.0
PYPI_SCPCLIENT_VER=0.4

# Examples settings
SS_EXAMPLES_USERNAME=$(ss-get slipstream-sixsq-username)
SS_EXAMPLES_PASSWORD=$(ss-get slipstream-sixsq-password)

### Advanced parameters

JETTY_SSL_PORT=443

SLIPSTREAM_SERVER_HOME=/opt/slipstream/server
SLIPSTREAM_SERVER_LOGS=$SLIPSTREAM_SERVER_HOME/logs

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
    isTrue $NGINX_PROXY && \
    	rpm -Uvh --force http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm

    # SlipStream
    [ "$RELEASE" == "true" ] && REPO_KIND=releases || REPO_KIND=snapshots

    cat > /etc/yum.repos.d/slipstream.repo <<EOF
[SlipStream-${REPO_KIND}]
name=SlipStream-${REPO_KIND}
baseurl=http://yum.sixsq.com/${REPO_KIND}/centos/6
enabled=1
protect=0
gpgcheck=0
metadata_expire=30s
autorefresh=1
type=rpm-md
EOF

}

function disable_selinux() {
    echo 0 > /selinux/enforce
    sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux /etc/selinux/config
}

function prepare_node () {
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

    yum install -y slipstream-hsqldb

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

    yum install -y --enablerepo=epel slipstream-client
}

function deploy_SlipStreamServer () {
    echo "Deploying SlipStream..."

    service slipstream stop || true

    yum install -y slipstream-server

    update_slipstream_configuration

    chkconfig --add slipstream
    service slipstream start

    deploy_nginx_proxy

    load_slipstream_examples
}

function update_slipstream_configuration() {

    sed -i -e "/^[a-z]/ s/slipstream.sixsq.com/${SS_HOSTNAME}/" \
           -e "/^[a-z]/ s/example.com/${SS_HOSTNAME}/" \
           $SLIPSTREAM_CONF

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
    isTrue $NGINX_PROXY || return 0

    # Install nginx and the configuratoin file for SlipStream
    yum install -y slipstream-server-nginx-conf

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
	cat > /etc/yum.repos.d/celar.repo <<EOF
[CELAR-${CELAR_REPO_KIND}]
name=CELAR-${CELAR_REPO_KIND}
baseurl=http://snf-175960.vm.okeanos.grnet.gr/nexus/content/repositories/${CELAR_REPO_KIND}
enabled=1
protect=0
gpgcheck=0
metadata_expire=30s
autorefresh=1
type=rpm-md
EOF
}

function deploy_CloudConnectors() {
	_add_celar_repo
	for connector in ${CONNECTORS}; do
		yum -y install slipstream-connector-${connector}
	done
}

function cleanup () {
    $CLEAN_PKG_CACHE
}

prepare_node
deploy_SlipStreamServerDependencies
deploy_SlipStreamClient
deploy_SlipStreamServer
deploy_CloudConnectors
cleanup

echo "::: SlipStream installed."

exit 0
