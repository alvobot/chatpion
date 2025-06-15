# ChatPion Dockerfile for EasyPanel
# Optimized for production deployment

FROM php:8.0-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libcurl4-openssl-dev \
    zip \
    unzip \
    mariadb-client \
    nano \
    cron \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    mysqli \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    curl \
    xml \
    json

# Install and configure OPcache for better performance
RUN docker-php-ext-install opcache
COPY <<EOF /usr/local/etc/php/conf.d/opcache.ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF

# Configure PHP
COPY <<EOF /usr/local/etc/php/conf.d/chatpion.ini
memory_limit = 512M
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
max_input_time = 300
max_input_vars = 10000
date.timezone = UTC
display_errors = Off
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
allow_url_fopen = On
EOF

# Enable Apache modules
RUN a2enmod rewrite headers expires deflate

# Configure Apache
COPY <<EOF /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    
    # Security headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
</VirtualHost>
EOF

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create necessary directories
RUN mkdir -p /var/www/html/upload \
    /var/www/html/upload_caster \
    /var/www/html/download \
    /var/www/html/application/cache \
    /var/log/chatpion

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . /var/www/html/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/upload \
    && chmod -R 777 /var/www/html/upload_caster \
    && chmod -R 777 /var/www/html/download \
    && chmod -R 777 /var/www/html/application/cache

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Copy deployment script
COPY deploy.sh /usr/local/bin/deploy.sh
RUN chmod +x /usr/local/bin/deploy.sh

# Create startup script
RUN echo '#!/bin/bash\n\
# Run deployment script\n\
/usr/local/bin/deploy.sh\n\
\n\
# Start cron\n\
service cron start\n\
\n\
# Start Apache in foreground\n\
apache2-foreground' > /usr/local/bin/start.sh \
    && chmod +x /usr/local/bin/start.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Run startup script
CMD ["/usr/local/bin/start.sh"]