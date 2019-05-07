#!/bin/bash

#########################
##     VARIABLES       ##
#########################
DB_NAME="nextcloud"
DB_USER="admin"
DB_PASSWORD="dwadawdwdadw"
DB_TYPE="mysql"

INSTALLATION_DIR=/usr/share/nginx/nextcloud
NGINX_CONFIG=/etc/nginx/conf.d/nextcloud.conf
NEXTCLOUD_CONFIG=$INSTALLATION_DIR/config/
HOSTNAME="localhost"
DATASTORE_BUCKET="test"

#################
## INIT SCRIPT ##
################
printf "Starting installation scprit..."
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

{
apt-get update && apt-get upgrade -y
} > /dev/null

########################
## INSTALL LEMP STACK ##
########################

#Install nginx
printf "Installing Nginx...\\n"
if service --status-all | grep -Fq 'nginx';
   then
        printf "nginx already exists\\n\\n"
else  
  apt install nginx -y > /dev/null;
  #service nginx enable;
  service nginx status;
  service nginx start;
  chown www-data /usr/share/nginx/html -R;
  mkdir nextcloud;
  cp nginx.conf $NGINX_CONFIG;
  sed -i 's/nextcloud.your-domain.com/'$HOSTNAME'/' $NGINX_CONFIG;
  sudo service nginx reload;
  
fi

#Install mariadb
printf "Installing MariaDB...\\n"
if service --status-all | grep -Fq 'mysql'; then
    printf "mysql is already installed\\n\\n"
else
  sudo apt install mariadb-server mariadb-client -y > /dev/null;
  sudo service mysql status; 
  sudo service mysql start;
  #sudo mysql_secure_installation;
  sudo mysql -u root -e "create database "$DATABASE_NAME"";
  sudo mysql -u root -e "GRANT ALL PRIVILEGES ON "$DATABASE_NAME".* TO '"$DATABASE_USER"'@'localhost' IDENTIFIED BY '"$DATABASE_PASSWORD"'";
fi

## installing php
if service --status-all | grep -Fq 'php7.2-fpm'; then
  printf "php is already installed\\n\\n"
else
  sudo apt install php7.2 php7.2-fpm php7.2-mysql php-common php7.2-cli php7.2-common php7.2-opcache php7.2-readline php7.2-xml php7.2-gd \
    php-imagick  php7.2-gd php7.2-json php7.2-curl  php7.2-zip php7.2-xml \
    php7.2-mbstring php7.2-bz2 php7.2-intl -y > /dev/null 2>&1;
    
  sudo service php7.2-fpm start;
  sudo service php7.2-fpm status;
fi

# Install redis
if service --status-all | grep -Fq 'redis'; then
  printf "redis is already installed\\n\\n"
else
  sudo apt install php-apcu redis-server php-redis -y > /dev/null 2>&1;
  sudo service redis start;
fi
##########################
## INSTALLING NEXTCLOUD ##
##########################

if [ -d $INSTALLATION_DIR ]; then
  printf "Nextcloud is already installed\\n\\n"
# Control will enter here if $DIRECTORY exists.
else
  # installing nextcloud
  wget https://download.nextcloud.com/server/releases/nextcloud-16.0.0.zip
  sudo apt install unzip
  sudo unzip nextcloud-16.0.0.zip -d /usr/share/nginx/
  sudo chown www-data:www-data $INSTALLATION_DIR -R
fi

# Create an initial configuration file.
instanceid=oc$(echo $HOSTNAME | sha1sum | fold -w 10 | head -n 1)
cat > $NEXTCLOUD_CONFIG/config.php <<EOF;
<?php
\$CONFIG = array (
  'datadirectory' => '/data',
  'memcache.local' => '\OC\Memcache\APCu',
  'instanceid' => '$instanceid',
);
?>
EOF

# Create an auto-configuration file to fill in database settings
# when the install script is run. Make an administrator account
# here or else the install can't finish.
adminpassword=$(dd if=/dev/urandom bs=1 count=40 2>/dev/null | sha1sum | fold -w 30 | head -n 1)
cat > $NEXTCLOUD_CONFIG/autoconfig.php <<EOF;
<?php
\$AUTOCONFIG = array (
  # storage/database
  'directory'     => '/data',
  'dbtype'        => '${DB_TYPE:-sqlite3}',
  'dbname'        => '${DB_NAME:-nextcloud}',
  'dbuser'        => '${DB_USER:-nextcloud}',
  'dbpass'        => '${DB_PASSWORD:-password}',
  'dbhost'        => '${DB_HOST:-nextcloud-db}',
  'dbtableprefix' => 'oc_',
EOF
if [[ ! -z "$ADMIN_USER"  ]]; then
  cat >> $NEXTCLOUD_CONFIG/autoconfig.php <<EOF;
  # create an administrator account with a random password so that
  # the user does not have to enter anything on first load of ownCloud
  'adminlogin'    => '${ADMIN_USER}',
  'adminpass'     => '${ADMIN_PASSWORD}',
EOF
fi
cat >> $NEXTCLOUD_CONFIG/autoconfig.php <<EOF;
);
?>
EOF

# Put S3 config into it's own config file
if [[ ! -z "$DATASTORE_BUCKET"  ]]; then
  cat >> $NEXTCLOUD_CONFIG/s3.config.php <<EOF;
<?php
\$CONFIG = array (
  # Setup S3 as a backend for primary storage
  'objectstore' => array (
    'class' => 'OC\\Files\\ObjectStore\\S3',
    'arguments' => array (
      'bucket' => '${DATASTORE_BUCKET}',
      'autocreate' => false,
      'key' => '${DATASTORE_KEY}',
      'secret' => '${DATASTORE_SECRET}',
      'hostname' => '${DATASTORE_HOST}',
      'port' => '${DATASTORE_PORT:-443}',
      'use_ssl' => true,
      // required for some non amazon s3 implementations
      'use_path_style' => %{DATASTORE_USE_PATH_STYLE},
    ),
  ),
);
?>
EOF
fi

echo "Starting automatic configuration..."
# Execute ownCloud's setup step, which creates the ownCloud database.
# It also wipes it if it exists. And it updates config.php with database
# settings and deletes the autoconfig.php file.
(cd $INSTALLATION_DIR; php index.php)
echo "Automatic configuration finished."

# Update config.php.
# * trusted_domains is reset to localhost by autoconfig starting with ownCloud 8.1.1,
#   so set it here. It also can change if the box's PRIMARY_HOSTNAME changes, so
#   this will make sure it has the right value.
# * Some settings weren't included in previous versions of Mail-in-a-Box.
# * We need to set the timezone to the system timezone to allow fail2ban to ban
#   users within the proper timeframe
# * We need to set the logdateformat to something that will work correctly with fail2ban
# Use PHP to read the settings file, modify it, and write out the new settings array.

CONFIG_TEMP=$(/bin/mktemp)
php <<EOF > $CONFIG_TEMP && mv $CONFIG_TEMP $NEXTCLOUD_CONFIG/config.php
<?php
include("/config/config.php");
//\$CONFIG['memcache.local'] = '\\OC\\Memcache\\Memcached';
\$CONFIG['mail_from_address'] = 'administrator'; # just the local part, matches our master administrator address
\$CONFIG['logtimezone'] = '$TZ';
\$CONFIG['logdateformat'] = 'Y-m-d H:i:s';
echo "<?php\n\\\$CONFIG = ";
var_export(\$CONFIG);
echo ";";
?>
EOF


sed -i "s/localhost/$DOMAIN/g" $NEXTCLOUD_CONFIG/config.php
# Enable/disable apps. Note that this must be done after the ownCloud setup.
# The firstrunwizard gave Josh all sorts of problems, so disabling that.
# user_external is what allows ownCloud to use IMAP for login. The contacts
# and calendar apps are the extensions we really care about here.
if [[ ! -z "$ADMIN_USER"  ]]; then
  occ app:disable firstrunwizard
fi

