#!/bin/bash

# ChatPion Deployment Script for EasyPanel
# Version: 1.0
# Compatible with ChatPion v9.4.3

set -e

echo "========================================="
echo "ChatPion Deployment Script for EasyPanel"
echo "========================================="

# Configuration
DB_HOST="${DB_HOST:-mysql}"
DB_USER="${DB_USER:-chatpion}"
DB_PASS="${DB_PASS:-chatpion123}"
DB_NAME="${DB_NAME:-chatpion_db}"
APP_URL="${APP_URL:-http://localhost}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if we're in the correct directory
if [ ! -f "index.php" ] || [ ! -d "application" ]; then
    print_error "This script must be run from the ChatPion root directory"
    exit 1
fi

print_status "Starting ChatPion deployment..."

# 1. Set correct permissions
print_status "Setting directory permissions..."
chmod -R 755 /code
chmod -R 777 /code/upload
chmod -R 777 /code/upload_caster
chmod -R 777 /code/download
chmod -R 777 /code/application/cache
chmod -R 777 /code/assets/backup_db

# 2. Configure database connection
print_status "Configuring database connection..."
cat > /code/application/config/database.php << EOF
<?php  if ( ! defined('BASEPATH')) exit('No direct script access allowed');

\$active_group = 'default';
\$active_record = FALSE;
\$db['default']['hostname'] = '${DB_HOST}';
\$db['default']['username'] = '${DB_USER}';
\$db['default']['password'] = '${DB_PASS}';
\$db['default']['database'] = '${DB_NAME}';
\$db['default']['dbdriver'] = 'mysqli';
\$db['default']['dbprefix'] = '';
\$db['default']['pconnect'] = FALSE;
\$db['default']['db_debug'] = TRUE;
\$db['default']['cache_on'] = FALSE;
\$db['default']['cachedir'] = '';
\$db['default']['char_set'] = 'utf8mb4';
\$db['default']['dbcollat'] = 'utf8mb4_unicode_ci';
\$db['default']['swap_pre'] = '';
\$db['default']['autoinit'] = TRUE;
\$db['default']['stricton'] = FALSE;
EOF

# 3. Update base URL in config
print_status "Updating application configuration..."
sed -i "s|\$config\['base_url'\] = .*|\$config['base_url'] = '${APP_URL}';|g" /code/application/config/config.php

# 4. Create .htaccess if not exists
if [ ! -f "/code/.htaccess" ]; then
    print_status "Creating .htaccess file..."
    cat > /code/.htaccess << 'EOF'
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    
    # Removes index.php from ExpressionEngine URLs
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ index.php?/$1 [L,QSA]
    
    # Prevents direct access to system folder
    RewriteCond %{REQUEST_URI} ^system.*
    RewriteRule ^(.*)$ /index.php?/$1 [L]
    
    # Prevents direct access to application folder
    RewriteCond %{REQUEST_URI} ^application.*
    RewriteRule ^(.*)$ /index.php?/$1 [L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
</IfModule>

# Compress text files
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript
</IfModule>

# Set proper MIME types
<IfModule mod_mime.c>
    AddType application/javascript js
    AddType text/css css
</IfModule>
EOF
fi

# 5. Install PHP dependencies
if [ -f "composer.json" ]; then
    print_status "Installing PHP dependencies..."
    if command -v composer &> /dev/null; then
        composer install --no-dev --optimize-autoloader
    else
        print_warning "Composer not found. Please install dependencies manually."
    fi
fi

# 6. Wait for MySQL to be ready
print_status "Waiting for MySQL to be ready..."
for i in {1..30}; do
    if mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" --silent &> /dev/null; then
        print_status "MySQL is ready!"
        break
    fi
    echo -n "."
    sleep 2
done

# 7. Import database if empty
print_status "Checking database..."
TABLES=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "SHOW TABLES" 2>/dev/null | wc -l)
if [ "$TABLES" -eq 0 ]; then
    print_status "Importing initial database..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < /code/assets/backup_db/initial_db.sql
    print_status "Database imported successfully!"
else
    print_warning "Database already contains tables. Skipping import."
fi

# 8. Create admin user if not exists
print_status "Setting up admin user..."
ADMIN_EXISTS=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "SELECT COUNT(*) FROM users WHERE user_type='Admin'" -s 2>/dev/null)
if [ "$ADMIN_EXISTS" -eq 0 ]; then
    ADMIN_PASS=$(openssl rand -base64 12)
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" << EOF
INSERT INTO users (name, email, password, user_type, status, deleted, activation_code) 
VALUES ('Admin', 'admin@chatpion.com', MD5('$ADMIN_PASS'), 'Admin', '1', '0', '');
EOF
    print_status "Admin user created!"
    print_warning "Admin credentials:"
    echo "  Email: admin@chatpion.com"
    echo "  Password: $ADMIN_PASS"
    echo "  Please change this password after first login!"
fi

# 9. Create cron job for scheduled tasks
print_status "Setting up cron jobs..."
if ! crontab -l 2>/dev/null | grep -q "chatpion_cron"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * curl -s ${APP_URL}/cron_job/index >/dev/null 2>&1 # chatpion_cron") | crontab -
    print_status "Cron job created!"
fi

# 10. Final checks
print_status "Running final checks..."

# Check PHP version
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
if (( $(echo "$PHP_VERSION >= 7.4" | bc -l) )); then
    print_status "PHP version $PHP_VERSION is compatible"
else
    print_error "PHP version $PHP_VERSION is not compatible. Requires >= 7.4"
fi

# Check required PHP extensions
REQUIRED_EXTENSIONS=("mysqli" "curl" "mbstring" "gd" "json" "zip")
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -q "^$ext$"; then
        print_status "PHP extension '$ext' is installed"
    else
        print_error "PHP extension '$ext' is missing"
    fi
done

echo ""
echo "========================================="
echo "Deployment completed!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Access your ChatPion installation at: ${APP_URL}"
echo "2. Complete the setup wizard if this is a fresh installation"
echo "3. Configure your Facebook/Instagram apps in the admin panel"
echo "4. Set up your payment gateways if using e-commerce features"
echo ""
print_warning "Remember to:"
echo "- Change the admin password"
echo "- Set up SSL certificate for production"
echo "- Configure email settings"
echo "- Review security settings"
echo ""