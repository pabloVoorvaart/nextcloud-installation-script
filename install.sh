#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

{
apt-get update && apt-get upgrade
} > /dev/null 2>&1

## installing lemp ##
if service --status-all | grep -Fq 'nginx';
   then
        printf "nginx already exists\\n"
else
   apt install nginx -y > /dev/null 2>&1;
   systemctl enable nginx;
   systemctl status nginx;
   chown www-data /usr/share/nginx/html -R;
   mkdir nextcloud;
   cp .nginx.conf /etc/nginx/conf.d/nextcloud.conf
   printf "Enter hostname for nextcloud:"
   read hostname
   printf hostname
fi

if service --status-all | grep -Fq 'mysql'; then
    printf "mysql is already installed\\n\\n"
else
  sudo apt install mariadb-server mariadb-client -y > /dev/null 2>&1;
  sudo systemctl status mysql; 
  sudo systemctl start mysql && sudo systemctl enable mysql;
  sudo mysql_secure_installation;
fi

## installing php ##
if service --status-all | grep -Fq 'php7.2-fpm'; then
  printf "php is already installed\\n\\n"
else
  sudo apt install php7.2 php7.2-fpm php7.2-mysql php-common php7.2-cli php7.2-common \
  php7.2-json php7.2-opcache php7.2-readline php7.2-mbstring php7.2-xml php7.2-gd php7.2-curl -y > /dev/null 2>&1; 
  sudo systemctl start php7.2-fpm;
  sudo systemctl enable php7.2-fpm;
  systemctl status php7.2-fpm;
fi

touch info.php
echo "<?php phpinfo(); ?>" >> info.php && mv info.php /usr/share/nginx/html/;
sudo service nginx restart;


if [ -d "/usr/share/nginx/nextcloud/" ]; then
    printf "Nextcloud is already installed\\n\\n"
  # Control will enter here if $DIRECTORY exists.
else
    ## installing nextcloud ##
    wget https://download.nextcloud.com/server/releases/nextcloud-16.0.0.zip
    sudo apt install unzip
    sudo unzip nextcloud-16.0.0.zip -d /usr/share/nginx/
    sudo chown www-data:www-data "/usr/share/nginx/nextcloud/" -R
fi

