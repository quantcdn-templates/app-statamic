FROM ghcr.io/quantcdn-templates/app-apache-php:8.4

# Remap www-data to UID/GID 1000 to match EFS access points (if not already done in base image)
RUN groupmod -g 1000 www-data 2>/dev/null || true && \
    usermod -u 1000 -g 1000 www-data 2>/dev/null || true && \
    # Fix ownership of existing www-data files after UID/GID change
    find / -user 33 -exec chown www-data {} \; 2>/dev/null || true && \
    find / -group 33 -exec chgrp www-data {} \; 2>/dev/null || true && \
    # Configure Apache to run as root but serve files as www-data
    sed -i 's/ErrorLog .*/ErrorLog \/dev\/stderr/' /etc/apache2/apache2.conf && \
    sed -i 's/CustomLog .*/CustomLog \/dev\/stdout combined/' /etc/apache2/sites-available/000-default.conf && \
    # Set Apache to run as root to bind to port 80, but PHP files served as www-data
    sed -i 's/export APACHE_RUN_USER=.*/export APACHE_RUN_USER=root/' /etc/apache2/envvars && \
    sed -i 's/export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=root/' /etc/apache2/envvars && \
    # Ensure Apache run directory exists and has correct permissions
    mkdir -p /var/run/apache2 && \
    chown -R www-data:www-data /var/run/apache2

# Enable Apache modules and configure remoteip for proper client IP handling
RUN set -eux; \
    # Enable Apache modules (some may already be enabled in base image)
    a2enmod rewrite 2>/dev/null || true; \
    a2enmod headers 2>/dev/null || true; \
    a2enmod proxy proxy_http 2>/dev/null || true; \
    a2enmod remoteip 2>/dev/null || true; \
    # Configure mod_remoteip for proper client IP handling
    echo 'RemoteIPHeader Quant-Client-IP' >> /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip 2>/dev/null || true

# Install any additional packages needed for Statamic (git is needed for Statamic)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        gosu \
    && rm -rf /var/lib/apt/lists/*

# Set PHP configuration
RUN { \
        echo 'opcache.memory_consumption=300'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=30000'; \
        echo 'opcache.revalidate_freq=60'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini && \
    echo 'memory_limit = 256M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini && \
    echo 'upload_max_filesize = 32M' >> /usr/local/etc/php/conf.d/docker-php-uploads.ini && \
    echo 'post_max_size = 48M' >> /usr/local/etc/php/conf.d/docker-php-uploads.ini

# Install Composer (rarely changes)
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# Set working directory
WORKDIR /var/www/html

# Copy dependency files first (changes occasionally)
COPY src/composer.json src/composer.lock* ./

# Install PHP dependencies (cached until composer files change)
RUN set -eux; \
    export COMPOSER_HOME="$(mktemp -d)"; \
    composer config apcu-autoloader true; \
    composer install --optimize-autoloader --apcu-autoloader --no-dev --no-scripts; \
    rm -rf "$COMPOSER_HOME"

# Configure Apache DocumentRoot for Laravel/Statamic public directory and fix ALL logging
RUN sed -i 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf && \
    # Fix all log directives to use stdout/stderr
    sed -i 's!ErrorLog.*!ErrorLog /dev/stderr!' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's!CustomLog.*!CustomLog /dev/stdout combined!' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's!ErrorLog.*!ErrorLog /dev/stderr!' /etc/apache2/sites-available/default-ssl.conf 2>/dev/null || true && \
    sed -i 's!CustomLog.*!CustomLog /dev/stdout combined!' /etc/apache2/sites-available/default-ssl.conf 2>/dev/null || true && \
    # Disable the other-vhosts-access-log configuration that causes permission issues
    a2disconf other-vhosts-access-log 2>/dev/null || true

# Quant Host header override (VirtualHost include approach)
RUN cat <<'EOF' > /etc/apache2/conf-available/quant-host-snippet.conf
<IfModule mod_rewrite.c>
    RewriteEngine On
    # Only accept well-formed hosts (optional port)
    RewriteCond %{HTTP:Quant-Orig-Host} ^([A-Za-z0-9.-]+(?::[0-9]+)?)$ [NC]
    RewriteRule ^ - [E=QUANT_HOST:%1]
</IfModule>
RequestHeader set Host "%{QUANT_HOST}e" env=QUANT_HOST
EOF

RUN a2enconf quant-host-snippet

RUN sed -i '/DocumentRoot \/var\/www\/html\/public/a\\n\t# Quant Host header override\n\tIncludeOptional /etc/apache2/conf-enabled/quant-host-snippet.conf' /etc/apache2/sites-available/000-default.conf

# Include Quant config include (synced into site root at runtime)
COPY quant/ /quant/
RUN chmod +x /quant/entrypoints.sh && \
    if [ -d /quant/entrypoints ]; then chmod +x /quant/entrypoints/* 2>/dev/null || true; fi

# Copy Quant PHP configuration files (allows users to add custom PHP configs)
COPY quant/php.ini.d/* /usr/local/etc/php/conf.d/

# Set up permissions (rarely changes)
RUN usermod -a -G www-data nobody 2>/dev/null || true && \
    usermod -a -G root nobody 2>/dev/null || true && \
    usermod -a -G www-data root 2>/dev/null || true

# Copy source code (changes frequently - do this last!)
COPY src/ /var/www/html/

# Keep a pristine copy of the flat-file content and users. On Quant Cloud both
# directories are persistent volumes that start empty and hide these files, so
# the entrypoint seeds them from here on first boot.
RUN mkdir -p /usr/src/statamic-seed && \
    cp -a /var/www/html/content /usr/src/statamic-seed/content && \
    cp -a /var/www/html/users /usr/src/statamic-seed/users

# Final setup that depends on source code
RUN set -eux; \
    # Copy .env.example to .env if .env doesn't exist
    if [ ! -f .env ]; then cp .env.example .env || true; fi; \
    # Run the Composer scripts that were skipped during install
    export COMPOSER_HOME="$(mktemp -d)"; \
    composer dump-autoload --optimize --apcu --no-dev; \
    rm -rf "$COMPOSER_HOME"; \
    # Create content directory if it doesn't exist
    mkdir -p /var/www/html/content; \
    # Create users directory for flat-file user storage
    mkdir -p /var/www/html/users; \
    # Set up permissions for Statamic directories
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/content /var/www/html/users; \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/content /var/www/html/users

# Set PATH
ENV PATH=${PATH}:/var/www/html/vendor/bin

# Expose ports
EXPOSE 80

# Start as root for entrypoints, then switch to www-data
# (entrypoints.sh will use gosu to switch to www-data for the main application)

# Use Quant entrypoints as the main entrypoint (run as root, simple)
ENTRYPOINT ["/quant/entrypoints.sh", "docker-php-entrypoint"]
CMD ["apache2-foreground"]
