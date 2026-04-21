FROM haproxy:2.8-alpine

USER root

# Keepalived pour VRRP
RUN apk add --no-cache keepalived

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY keepalived.conf /etc/keepalived/keepalived.conf

# Crée le répertoire du socket admin
RUN mkdir -p /run/haproxy

EXPOSE 80 8404

# Démarre HAProxy + Keepalived
CMD sh -c "keepalived --dont-fork --log-console & haproxy -f /usr/local/etc/haproxy/haproxy.cfg -W"
