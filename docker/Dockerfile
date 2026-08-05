FROM composer:2 AS composer

FROM php:8.3-fpm-alpine AS app
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Install required dependencies
RUN apk --no-cache add \
    su-exec \
    postgresql-dev \
    libpng-dev \
    zlib-dev \
    oniguruma-dev \
    libzip-dev \
    zip \
    unzip \
    autoconf \
    gcc \
    g++ \
    make \
    bash \
    postgresql-client \
    linux-headers \
    libtool \
    nodejs \
    npm

# Add extra PHP dependencies
RUN docker-php-ext-install pdo pgsql pdo_pgsql gd bcmath zip exif pcntl \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && docker-php-ext-configure pcntl --enable-pcntl

WORKDIR /usr/share/caddy/html/

# Copy composer files first for better layer caching
COPY composer.json composer.lock* ./
RUN composer install \
  --no-interaction \
  --no-progress \
  --no-scripts \
  --no-dev \
  --optimize-autoloader \
  && composer clear-cache

# Copy package files for npm layer caching
COPY package.json pnpm-lock.yaml* ./
ENV NODE_OPTIONS=--max-old-space-size=1536
RUN npm install --no-audit --no-fund --prefer-offline \
  && npm cache clean --force

# Copy files needed for Vite build (keep layer cache when source changes)
COPY artisan ./
COPY bootstrap ./bootstrap
COPY config ./config
COPY public ./public
COPY resources ./resources
COPY routes ./routes
COPY vite.config.ts tsconfig.json* ./
RUN NODE_OPTIONS=--max-old-space-size=1536 npm run build \
  && rm -rf node_modules \
  && npm cache clean --force

# Copy remaining application code
COPY . .

# Set permissions and prepare Laravel
RUN mkdir -p storage/framework/cache/data \
  && mkdir -p storage/framework/sessions \
  && mkdir -p storage/framework/views \
  && mkdir -p storage/logs \
  && mkdir -p storage/app/public \
  && mkdir -p bootstrap/cache \
  && php artisan package:discover --ansi \
  && chown -R www-data:www-data /usr/share/caddy/html/storage \
  && chown -R www-data:www-data /usr/share/caddy/html/bootstrap/cache \
  && chmod -R 775 /usr/share/caddy/html/storage \
  && chmod -R 775 /usr/share/caddy/html/bootstrap/cache

COPY ./docker/php-fpm-entrypoint /usr/local/bin/php-entrypoint

RUN chmod a+x /usr/local/bin/*

FROM app

ENTRYPOINT ["/usr/local/bin/php-entrypoint"]

CMD ["php-fpm"]
