#!/bin/sh
set -e

# Démarrer rsyslog pour que HAProxy puisse écrire via /dev/log
rsyslogd
sleep 1

# Injecter KEEPALIVED_STATE et KEEPALIVED_PRIORITY dans le template
envsubst '${KEEPALIVED_STATE} ${KEEPALIVED_PRIORITY}' \
    < /etc/keepalived/keepalived.conf.tpl \
    > /etc/keepalived/keepalived.conf

keepalived --dont-fork --log-console &

exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg -W
