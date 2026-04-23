FROM mariadb:10.11

# Crée /var/log/mysql avec les bonnes permissions (mysql user = uid 999)
RUN mkdir -p /var/log/mysql && chown 999:999 /var/log/mysql

COPY my.cnf /etc/mysql/conf.d/replication.cnf
# init-slave.sql est appliqué par Ansible après démarrage du master

EXPOSE 3306

HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD mysqladmin ping -h localhost -u root -p$$MYSQL_ROOT_PASSWORD || exit 1
