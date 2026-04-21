FROM haproxy:2.8-alpine

USER root

# Keepalived pour VRRP + envsubst pour le templating
RUN apk add --no-cache keepalived gettext

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY keepalived.conf /etc/keepalived/keepalived.conf.tpl

# Crée le répertoire du socket admin
RUN mkdir -p /run/haproxy

EXPOSE 80 8404

# Injecte KEEPALIVED_STATE et KEEPALIVED_PRIORITY avant de démarrer
CMD sh -c "envsubst '\${KEEPALIVED_STATE} \${KEEPALIVED_PRIORITY}' \
    < /etc/keepalived/keepalived.conf.tpl \
    > /etc/keepalived/keepalived.conf && \
    keepalived --dont-fork --log-console & \
    haproxy -f /usr/local/etc/haproxy/haproxy.cfg -W"
