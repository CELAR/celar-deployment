#!/bin/bash

cat > /etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [1:72]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 443 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 8080 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 8180 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 8181 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 8280 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 4242 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 4243 -j ACCEPT
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 4245 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF

service iptables restart
