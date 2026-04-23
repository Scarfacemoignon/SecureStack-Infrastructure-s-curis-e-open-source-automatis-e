FROM haproxy:2.8-alpine

USER root

# Keepalived pour VRRP, envsubst pour le templating, rsyslog pour capturer les logs HAProxy
RUN apk add --no-cache keepalived gettext rsyslog

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY keepalived.conf /etc/keepalived/keepalived.conf.tpl
COPY rsyslog.conf /etc/rsyslog.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    mkdir -p /run/haproxy /var/log/haproxy /var/spool/rsyslog

EXPOSE 80 8404

ENTRYPOINT ["/entrypoint.sh"]
