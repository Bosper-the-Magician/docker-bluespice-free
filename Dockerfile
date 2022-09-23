FROM ubuntu:20.04 as main

RUN apt-get update \
	&& apt-get -y --no-install-recommends install \
	gnupg2 \
	curl \
	ca-certificates \
	&& apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 14AA40EC0831756756D7F66C4F4EA0AAE5267A6C \
	&& echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu focal main" >> /etc/apt/sources.list \
	&& echo "deb-src http://ppa.launchpad.net/ondrej/php/ubuntu focal main" >> /etc/apt/sources.list \
	&& apt-get update
FROM main as bsbuild
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive
ADD https://bluespice.com/filebase/bluespice-free-4-2/ /opt/BlueSpice-free.zip

# ADD https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 /tmp/
COPY ./phantomjs-2.1.1-linux-x86_64.tar.bz2 /tmp/

RUN apt-get -y --no-install-recommends install \
	bzip2 \
	&& cd /tmp \
	&& tar xjf phantomjs-2.1.1-linux-x86_64.tar.bz2 \
	&& mv /tmp/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin \
	&& chmod +x /usr/local/bin/phantomjs \
	&& rm -rf /tmp/phantomjs-2.1.1-linux-x86_64 \
	&& rm -rf /tmp/phantomjs-2.1.1-linux-x86_64.tar.bz2

FROM main as bsbase
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive
ADD https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-6.8.23.deb /tmp
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
	&& apt-get -y --no-install-recommends install \
	python3 \
	cron \
	logrotate \
	nginx \
	php7.4-fpm \
	php7.4-xml \
	php7.4-mbstring \
	php7.4-curl \
	unzip \
	php7.4-zip \
	php7.4-tidy \
	php7.4-gd \
	php7.4-cli \
	php7.4-json \
	php7.4-mysql \
	php7.4-ldap \
	php7.4-opcache \
	php7.4-memcache \
	php7.4-intl \
	memcached \
	mariadb-server \
	jetty9 \
	nodejs \
	imagemagick \
	poppler-utils \
	ghostscript \
	vim \
	&& mkdir -p /opt/docker/pkg \
	&& cd /tmp \
	&& dpkg -i /tmp/elasticsearch-oss-6.8.23.deb \
	&& /usr/share/elasticsearch/bin/elasticsearch-plugin install -b ingest-attachment \
	&& mkdir -p /var/run/memcached \
	&& mkdir -p /run/php \
	&& apt-get -y auto-remove \
	&& apt-get -y clean \
	&& apt-get -y autoclean \
	&& rm -Rf /var/lib/apt/lists/* \
	&& rm -Rf /tmp/* \
	&& find /var/log -type f -delete \
	&& ln -s /usr/bin/python3 /usr/bin/python

FROM bsbase
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive
COPY ./includes/init/init.py /opt/docker/
COPY ./includes/install-scripts /opt/docker/install-scripts
COPY ./includes/misc/scripts/setwikiperm.sh /opt/docker/
RUN chmod a+x /opt/docker/*.py \
	&& chmod a+x /opt/docker/*.sh \
	&& chmod a+x /opt/docker/install-scripts/*.sh \
	&& mkdir -p /opt/docker/pkg \
	&& mkdir -p /opt/docker/bluespice-data/extensions/BluespiceFoundation \
	&& mkdir -p /opt/docker/bluespice-data/settings.d \
	&& mkdir /data \
	&& touch /opt/docker/.firstrun
COPY ./includes/bluespice-data /opt/docker/bluespice-data
COPY ./includes/misc/cron/bluespice /etc/cron.d/
COPY ./includes/misc/mysql/mysqld.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY ./includes/misc/nginx/bluespice.conf /etc/nginx/sites-available/
COPY ./includes/misc/nginx/bluespice-ssl.conf /etc/nginx/sites-available/
COPY ./includes/misc/nginx/fastcgi.conf /etc/nginx/
COPY ./includes/misc/nginx/nginx.conf /etc/nginx/
COPY ./includes/misc/nginx/nginx.conf /etc/nginx/
COPY ./includes/misc/php/php.ini /etc/php/7.4/fpm/
COPY ./includes/misc/php/www.conf /etc/php/7.4/fpm/pool.d/
COPY ./includes/misc/php/opcache.blacklist /etc/php/opcache.blacklist
COPY --from=bsbuild /opt/BlueSpice-free.zip /opt/docker/pkg/
RUN rm /etc/nginx/sites-enabled/* \
	&& ln -s /etc/nginx/sites-available/bluespice.conf /etc/nginx/sites-enabled/
COPY ./includes/misc/pingback/pingback.js /opt/docker/
COPY --from=bsbuild /usr/local/bin/phantomjs /usr/local/bin
RUN echo "JAVA_OPTIONS=\"\-Xms512m -Xmx1024m -Djetty.home=127.0.0.1\"" >> /etc/default/jetty9; \
	chown -Rf www-data:www-data /run/php

# RUN pip install python-dotenv

# ARG WIKI_INSTALL_DIR
# ARG WIKI_BACKUP_LIMIT
# ARG DISABLE_PINGBACK
# ARG BS_URL
# ARG BS_LANG
# ARG BS_USER
# ARG BS_PASSWORD

# ENV WIKI_INSTALL_DIR $WIKI_INSTALL_DIR
# ENV WIKI_BACKUP_LIMIT $WIKI_BACKUP_LIMIT
# ENV DISABLE_PINGBACK $DISABLE_PINGBACK
# ENV BS_URL $BS_URL
# ENV BS_LANG $BS_LANG
# ENV BS_USER $BS_USER
# ENV BS_PASSWORD $BS_PASSWORD
# ENTRYPOINT /opt/docker/init.py && tail -f /dev/null
# ENTRYPOINT /opt/docker/install-scripts/init_with_args.sh && tail -f /dev/null
# RUN /opt/docker/install-scripts/init_with_args.sh ${WIKI_INSTALL_DIR} ${WIKI_BACKUP_LIMIT} ${DISABLE_PINGBACK} ${BS_URL} ${BS_LANG} ${BS_USER} ${BS_PASSWORD}
# CMD ["/opt/docker/install-scripts/init_with_args.sh", ${WIKI_INSTALL_DIR}, ${WIKI_BACKUP_LIMIT}, ${DISABLE_PINGBACK}, ${BS_URL}, ${BS_LANG}, ${BS_USER}, ${BS_PASSWORD}]
# ENTRYPOINT /opt/docker/install-scripts/init_with_args.sh ${WIKI_INSTALL_DIR} ${WIKI_BACKUP_LIMIT} ${DISABLE_PINGBACK} ${BS_URL} ${BS_LANG} ${BS_USER} ${BS_PASSWORD} && tail -f /dev/null
# ENTRYPOINT /opt/docker/install-scripts/init_with_args.sh ${WIKI_INSTALL_DIR} ${WIKI_BACKUP_LIMIT} ${DISABLE_PINGBACK} ${BS_URL} ${BS_LANG} ${BS_USER} ${BS_PASSWORD}
ENTRYPOINT /opt/docker/install-scripts/init_with_args.sh

# ARG WIKI_BACKUP_LIMIT
# ARG WIKI_BACKUP_DIR
# ARG DISABLE_PINGBACK
# ARG BS_URL
# ARG BS_LANG
# ARG BS_USER
# ARG BS_PASSWORD

# ENV WIKI_BACKUP_LIMIT $WIKI_BACKUP_LIMIT
# ENV WIKI_BACKUP_DIR $WIKI_BACKUP_DIR
# ENV DISABLE_PINGBACK $DISABLE_PINGBACK
# ENV BS_URL $BS_URL
# ENV BS_LANG $BS_LANG
# ENV BS_USER $BS_USER
# ENV BS_PASSWORD $BS_PASSWORD

# ENTRYPOINT /opt/docker/init.sh \
# 	--wiki-backup-limit ${WIKI_BACKUP_LIMIT} \
# 	--wiki-backup-dir ${WIKI_BACKUP_DIR} \
# 	--disable-pingback ${DISABLE_PINGBACK} \
# 	--bs-url ${BS_URL} \
# 	--bs-lang ${BS_LANG}
# ENTRYPOINT python3 /opt/docker/init.py \
# 	--wiki_backup_limit ${WIKI_BACKUP_LIMIT} \
# 	--disable_pingback ${DISABLE_PINGBACK} \
# 	--bs_url ${BS_URL} \
# 	--bs_lang ${BS_LANG} \
# 	--bs_user ${BS_USER} \
# 	--bs_password ${BS_PASSWORD} >> /dev/logs 2>&1
# ENTRYPOINT /opt/docker/init.py >> /dev/logs 2>&1

# ENTRYPOINT python3 /opt/docker/init.py \
# 	--wiki_backup_limit 4 \
# 	--disable_pingback yes \
# 	--bs_url http://localhost \
# 	--bs_lang en \
# 	--bs_user WikiSysop \
# 	--bs_password PleaseChangeMe

# ENTRYPOINT /opt/docker/init.sh \
# 	--wiki_backup_limit 5 \
# 	--wiki_backup_dir /home/jonty/Developer/docker-bluespice-free/temp/wiki_backups \
# 	--disable_pingback yes \
# 	--bs_url http://localhost \
# 	--bs_lang en \
# 	--bs_user WikiSysop \
# 	--bs_password PleaseChangeMe
