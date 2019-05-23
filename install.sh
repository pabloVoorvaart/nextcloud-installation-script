#!/bin/bash

#########################
##     VARIABLES       ##
#########################
DB_NAME="nextcloud"
DB_USER="admin"
DB_PASSWORD="dwadawdwdadw"
DB_TYPE="mysql"

ADMIN_USER="admin"
ADMIN_PASSWORD="pepitogrillo"

INSTALLATION_DIR=/usr/share/nginx/nextcloud
NGINX_CONFIG=/etc/nginx/conf.d/nextcloud.conf
NEXTCLOUD_CONFIG=$INSTALLATION_DIR/config/
HOSTNAME="localhost"
DATASTORE_BUCKET="nextcloudev"

#################
## INIT SCRIPT ##
################
printf "Starting installation scprit... \\n\\n";
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
printf "Installing Nginx...\\n";
if service --status-all | grep -Fq 'nginx'; then
        printf "\\tNginx is already installed!\\n\\n";
else  
  apt install nginx -y > /dev/null 2>&1;
  #service nginx status;
  service nginx start;
  printf "\\tNginx installed succesfully!\\n\\n";
fi

#Install mariadb
printf "Installing MariaDB...\\n";
if service --status-all | grep -Fq 'mysql'; then
    printf "\\tMysql is already installed!\\n\\n";
else
  sudo apt install mariadb-server mariadb-client -y > /dev/null 2>&1;
  # sudo service mysql status; 
  sudo service mysql start;
  #sudo mysql_secure_installation;
  printf "\\tMysql installed succesfully!\\n\\n";
fi

## installing php
printf "Installing php7.2...\\n";
if service --status-all | grep -Fq 'php7.2-fpm'; then
    printf "\\tPhp is already installed!\\n\\n";
else
  sudo apt install php7.2 php7.2-fpm php7.2-mysql php-common php7.2-cli php7.2-common php7.2-opcache php7.2-readline php7.2-xml php7.2-gd \
    php-imagick  php7.2-gd php7.2-json php7.2-curl  php7.2-zip php7.2-xml \
    php7.2-mbstring php7.2-bz2 php7.2-intl -y > /dev/null 2>&1;  
  sudo service php7.2-fpm start;
  printf "\\tPhp installed succesuflly!\\n";
  
  printf "\\tTweaking php...\\n\\n"
  sleep 2;
  sudo sed -i "s/post_max_size = .*/post_max_size = 2000M/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/memory_limit = .*/memory_limit = 3000M/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/max_execution_time = .*/max_execution_time = 3600/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/; max_input_vars = .*/max_input_vars = 5000/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;clear_env = no/clear_env = no/" /etc/php/7.2/fpm/pool.d/www.conf
  sudo sed -i "s/;opcache.enable=0/opcache.enable=1/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;opcache.enable_cli=0/opcache.enable_cli=1/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;opcache.interned_strings_buffer=4/opcache.interned_strings_buffer=8/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=10000/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;opcache.memory_consumption=64/opcache.memory_consumption=128/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;opcache.save_comments=1/opcache.save_comments=1/" /etc/php/7.2/fpm/php.ini
  sudo sed -i "s/;opcache.revalidate_freq=2/opcache.revalidate_freq=1/" /etc/php/7.2/fpm/php.ini

  sudo service php7.2-fpm restart;
fi

# Install redis
printf "Installing redis...\\n";
if service --status-all | grep -Fq 'redis'; then
  printf "\\tRedis is already installed\\n\\n";
else
  sudo apt install php-apcu redis-server php-redis -y > /dev/null 2>&1;
  sudo service redis start;
  printf "\\tRedis installed succesfully\\n\\n";

fi

##########################
## INSTALLING NEXTCLOUD ##
##########################
printf "Installing Nextcloud...\\n" 

if [ -d $INSTALLATION_DIR ]; then
  printf "\\tNextcloud is already installed\\n\\n"
# Control will enter here if $DIRECTORY exists.
else
 # update nginx configuraton
  sudo cp nginx.conf $NGINX_CONFIG;
  sed -i 's/nextcloud.your-domain.com/'$HOSTNAME'/' $NGINX_CONFIG;
  service nginx reload;

  # Creating mysql user and db, it wont overide.
  sudo mysql -u root -e "create database "$DB_NAME"";
  sudo mysql -u root -e "GRANT ALL PRIVILEGES ON "$DB_NAME".* TO '"$DB_USER"'@'localhost' IDENTIFIED BY '"$DB_PASSWORD"'";


  # installing nextcloud
  wget https://download.nextcloud.com/server/releases/nextcloud-16.0.0.zip;
  sudo apt install unzip;
  sudo unzip nextcloud-16.0.0.zip -d /usr/share/nginx/ >/dev/null;
  sudo chown www-data:www-data $INSTALLATION_DIR -R;
  sudo mkdir $INSTALLATION_DIR/data;
  sudo chown www-data:www-data $INSTALLATION_DIR/data -R;
  rm nextcloud-16.0.0.zip;
fi

# Create an auto-configuration file to fill in database settings
# when the install script is run. Make an administrator account
# here or else the install can't finish.
adminpassword=$(dd if=/dev/urandom bs=1 count=40 2>/dev/null | sha1sum | fold -w 30 | head -n 1)
cat > $NEXTCLOUD_CONFIG/autoconfig.php <<EOF;
<?php
\$AUTOCONFIG = array (
  # storage/database
  'directory'     => '/usr/share/nginx/nextcloud/data',
  'dbtype'        => '${DB_TYPE:-sqlite3}',
  'dbname'        => '${DB_NAME:-nextcloud}',
  'dbuser'        => '${DB_USER:-nextcloud}',
  'dbpass'        => '${DB_PASSWORD:-password}',
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

echo "Starting automatic configuration..."
# Execute ownCloud's setup step, which creates the ownCloud database.
# It also wipes it if it exists. And it updates config.php with database
# settings and deletes the autoconfig.php file.
curl $HOSTNAME/index.php
echo "Automatic configuration finished."

printf "\\tCreating config file for Redis....\\n"
cat >> $NEXTCLOUD_CONFIG/redis.config.php <<EOF;
<?php
\$CONFIG = array (
  /**'memcache.local' => '\\OC\\Memcache\\APCu',                                                                                                                                       
  'memcache.local' => '\\OC\\Memcache\\Redis',**/
  'memcache.locking' => '\\OC\\Memcache\\Redis',                                                                                                                                            
  'redis' =>                                                                                                                                                                                
  array (                                                                                                                                                                                   
    'host' => '/var/run/redis/redis-server.sock',                                                                                                                                           
    'port' => 0,                                                                                                                                                                            
  ), 
);
?>
EOF


# Put S3 config into it's own config file
printf "\\tAdding s3 to nextcloud..."
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
      'key' => 'AKIA2JNTK7ECDQYEO26A',
      'secret' => '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',
      'use_ssl' => true,
    ),
  ),
);
?>
EOF
fi
printf "\\tDone, enjoy Nextcloud :)"