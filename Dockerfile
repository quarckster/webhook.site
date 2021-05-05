##############################################
# Stage 1: Install node dependencies and run gulp
##############################################

FROM node:11 as npm
WORKDIR /app

COPY package-lock.json package.json /app
RUN npm install

COPY resources /app/resources
COPY gulpfile.js /app
RUN npm run gulp

##############################################
# Stage 2: Composer, nginx and fpm
##############################################

FROM bkuhl/fpm-nginx:7.3
WORKDIR /var/www/html

# Contains laravel echo server proxy configuration
COPY app /var/www/html/app
COPY artisan /var/www/html
COPY bootstrap /var/www/html/bootstrap
COPY composer.json composer.lock /var/www/html
COPY config /var/www/html/config
COPY database /var/www/html/database
COPY nginx.conf /etc/nginx/conf.d
COPY public /var/www/html/public
COPY resources /var/www/html/resources
COPY storage /var/www/html/storage
COPY --from=npm /app/public/css /var/www/html/public/css
COPY --from=npm /app/public/js /var/www/html/public/js

RUN composer global require hirak/prestissimo && \
    composer install --no-interaction --no-autoloader --no-dev --prefer-dist --no-scripts && \
    rm -rf /home/www-data/.composer/cache && \
    composer dump-autoload --optimize --no-dev && \
    touch /var/www/html/database/database.sqlite && \
    php artisan optimize && \
    php artisan migrate && \
    wget -O /tmp/s6-overlay-amd64-installer \
            https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer && \
    chmod +x /tmp/s6-overlay-amd64-installer && \
    /tmp/s6-overlay-amd64-installer / && \
    rm -f /tmp/s6-overlay-amd64-installer && \
    sed -i "/user  nginx;/d" /etc/nginx/nginx.conf && \ 
    chown -LR 1001:0 /var && \
    chgrp -LR 0 /var/ && \
    find -L /var/ -exec chmod -R a+rwx {} \;

USER 1001
