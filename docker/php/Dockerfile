ARG PHP_VERSION=8.3
FROM wordpress:php${PHP_VERSION}-fpm-alpine

# Pin/extend here so PHP upgrades are a one-line ARG bump + redeploy,
# independent of nginx or the WordPress files volume.
RUN apk add --no-cache imagemagick imagemagick-dev \
    && docker-php-ext-install opcache \
    && docker-php-ext-enable opcache

COPY php.ini /usr/local/etc/php/conf.d/zz-wp-tuning.ini
COPY zz-docker-pool.conf /usr/local/etc/php-fpm.d/zz-docker-pool.conf