ARG MARIADB_VERSION=latest
FROM mariadb:${MARIADB_VERSION}

MAINTAINER Mahmoud Zalt <mahmoud@zalt.me>

ADD my.cnf /etc/mysql/conf.d/my.cnf

CMD ["mysqld"]

EXPOSE 3306
