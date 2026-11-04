# syntax=docker/dockerfile:1

ARG PHP_VERSION=8.5.12

# ---------- runtime ----------
FROM php:${PHP_VERSION}-fpm-alpine AS runtime

ARG PHP_VERSION

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# nginx + supervisor from Alpine repos; PHP extensions via installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN set -e \
    && apk add --no-cache \
        nginx \
        supervisor \
        curl \
    && (grep -q ^www-data: /etc/passwd || adduser -D -H -u 82 -s /sbin/nologin www-data) \
    && install-php-extensions \
        intl \
        pdo_mysql \
        mysqli \
        opcache \
        zip \
        gd \
        bcmath \
        exif \
        soap \
        xsl \
        bz2 \
        ftp \
        pdo_pgsql \
        pgsql \
        gmp \
    && docker-php-source delete

# Composer/system tools
RUN apk add --no-cache git unzip

# nginx config
COPY docker/nginx/default.conf /etc/nginx/http.d/zz-default.conf
COPY docker/nginx/security.conf /etc/nginx/http.d/zz-security.conf
RUN rm /etc/nginx/http.d/default.conf

# php-fpm pool: unix socket (single-container setup)
COPY docker/php-fpm/zz-pool.conf /usr/local/etc/php-fpm.d/zz-pool.conf

# PHP overrides (same file/API as themusicdev/php-apache)
COPY docker/php/zz-app.ini /usr/local/etc/php/conf.d/zz-app.ini

# supervisor
COPY docker/supervisord.conf /etc/supervisord.conf

# entrypoint
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Generic document root; child Dockerfiles override per framework
# (CakePHP: /var/www/html/webroot, Slim: /var/www/html/public)
ENV DOCROOT=/var/www/html

WORKDIR /var/www/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS -o /dev/null http://127.0.0.1/ || exit 1

LABEL org.opencontainers.image.title="themusicdev/php-nginx-alpine" \
      org.opencontainers.image.description="Slim (Alpine) nginx + PHP-FPM 8.5 runtime for CakePHP and Slim apps" \
      org.opencontainers.image.source="https://github.com/TheMusicDev/php-nginx-alpine" \
      org.opencontainers.image.url="https://github.com/TheMusicDev/php-nginx-alpine" \
      org.opencontainers.image.version="${PHP_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="docker.io/library/php:${PHP_VERSION}-fpm-alpine"

# supervisord manages php-fpm + nginx; entrypoint fixes config/docroot then execs it
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []

# ---------- dev ----------
FROM runtime AS dev

ARG PHP_VERSION

RUN set -e \
    && apk add --no-cache \
        nodejs \
        npm \
        mariadb-client \
    && install-php-extensions xdebug \
    && docker-php-source delete \
    && mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# Xdebug off by default; enable per-container with XDEBUG_MODE (e.g. debug)
RUN { echo "xdebug.mode=off"; } > /usr/local/etc/php/conf.d/zz-xdebug.ini

ENV XDEBUG_MODE=off