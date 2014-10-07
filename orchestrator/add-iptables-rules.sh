#!/bin/bash

iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited

#add custom rules for CELAR MODULES

#rule for accessing JCatascopia
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT

#rule for accessing MELA Data Service
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 8180 -j ACCEPT 

#rule for accessing MELA Analysis Service
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 8181 -j ACCEPT 

#rule for accessing rSYBL
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 8280 -j ACCEPT 

#rule for JCatascopia Agents connecting to Server
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 4242 -j ACCEPT 
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 4243 -j ACCEPT 
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 4245 -j ACCEPT 

#add the last two rejects statements back
#in testing, if I add rules after this reject is mentioned, the rules are ignored
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited

service iptables save

