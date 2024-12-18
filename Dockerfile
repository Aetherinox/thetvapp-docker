# syntax=docker/dockerfile:1

# #
#   @file           Dockerfile
#   @about          This docker file installs:
#                       - nginx
#                       - php-fpm
#                       - theapptv
# #

# #
#   Base Image
#   This container uses a modified version of the Linux server alpine image
# #

FROM ghcr.io/linuxserver/baseimage-alpine:3.20

# #
#   Set Labels
# #

LABEL maintainer="Aetherinox"
LABEL org.opencontainers.image.authors="Aetherinox"
LABEL org.opencontainers.image.vendor="Aetherinox"
LABEL org.opencontainers.image.title="TheTVApp Grabber"
LABEL org.opencontainers.image.description="thetvapp image by Aetherinox"
LABEL org.opencontainers.image.source="https://github.com/Aetherinox/thetvapp-docker"
LABEL org.opencontainers.image.documentation="https://github.com/Aetherinox/thetvapp-docker"
LABEL org.opencontainers.image.url="https://github.com/Aetherinox/thetvapp-docker"
LABEL org.opencontainers.image.licenses="MIT"
LABEL build_version="1.0.0"

# #
#   Set Args
# #

ARG BUILD_DATE
ARG VERSION
ARG NGINX_VERSION
ARG CRON_TIME
ENV CRON_TIME="0/60 * * * *"
ENV TZ="Etc/UTC"

ENV URL_XML="https://raw.githubusercontent.com/dtankdempse/thetvapp-m3u/refs/heads/main/guide/epg.xml"
ENV URL_XML_GZ="https://raw.githubusercontent.com/dtankdempse/thetvapp-m3u/refs/heads/main/guide/epg.xml.gz"
ENV URL_M3U="https://thetvapp-m3u.data-search.workers.dev/playlist"
ENV FILE_NAME="thetvapp"

ENV PORT_HTTP=80
ENV PORT_HTTPS=443

# #
#   Install
# #

RUN \
  if [ -z ${NGINX_VERSION+x} ]; then \
      NGINX_VERSION=$(curl -sL "http://dl-cdn.alpinelinux.org/alpine/v3.20/main/x86_64/APKINDEX.tar.gz" | tar -xz -C /tmp \
      && awk '/^P:nginx$/,/V:/' /tmp/APKINDEX | sed -n 2p | sed 's/^V://'); \
  fi && \
  apk add --no-cache \
      wget \
      logrotate \
      openssl \
      apache2-utils \
      nginx \
      nginx==${NGINX_VERSION} \
      nginx-mod-http-fancyindex==${NGINX_VERSION} && \
  echo "**** Install Build Packages ****" && \
  echo "**** Configure Nginx ****" && \
  echo 'fastcgi_param  HTTP_PROXY         ""; # https://httpoxy.org/' >> \
      /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  PATH_INFO          $fastcgi_path_info; # http://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info' >> \
      /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name; # https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/#connecting-nginx-to-php-fpm' >> \
      /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  SERVER_NAME        $host; # Send HTTP_HOST as SERVER_NAME. If HTTP_HOST is blank, send the value of server_name from nginx (default is `_`)' >> \
      /etc/nginx/fastcgi_params && \
  rm -f /etc/nginx/http.d/default.conf && \
  rm -f /etc/nginx/conf.d/stream.conf && \
  rm -f /config/www/index.html && \
  echo "**** Setup Logrotate ****" && \
  sed -i "s#/var/log/messages {}.*# #g" \
      /etc/logrotate.conf && \
  sed -i 's#/usr/sbin/logrotate /etc/logrotate.conf#/usr/sbin/logrotate /etc/logrotate.conf -s /config/log/logrotate.status#g' \
      /etc/periodic/daily/logrotate

# #
#   Set work directory
# #

WORKDIR /config/www

# #
#   add local files
# #

COPY root/ /

# #
#   ports and volumes
# #

EXPOSE ${PORT_HTTP} ${PORT_HTTPS}

# #
#   Add Cron Task Files
# #

ADD run.sh /
ADD download.sh /

# #
#   In case user sets up the cron for a longer duration, do a first run
#   and then keep the container running. Hacky, but whatever.
# #

CMD ["sh", "-c", "/run.sh ; /download.sh ; tail -f /dev/null"]
