#!/bin/bash

#########################
##     VARIABLES       ##
#########################
DATABASE_NAME="nextcloud"
DATABASE_USER="admin"
DATABASE_PASSWORD="dwadawdwdadw"
INSTALLATION_DIR="/usr/share/nginx/nextcloud/"
NGINX_CONFIG="/etc/nginx/conf.d/nextcloud.conf"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

{
apt-get update && apt-get upgrade -y
}

####
## installing lemp ##
if service --status-all | grep -Fq 'nginx';
   then
        printf "nginx already exists\\n"
else  
  apt install nginx -y;
  systemctl enable nginx;
  systemctl status nginx;
  chown www-data /usr/share/nginx/html -R;
  mkdir nextcloud;
  cp nginx.conf $NGINX_CONFIG;
  printf "Enter hostname for nextcloud:";
  read hostname;
  printf hostname;
  sed -i 's/nextcloud.your-domain.com/'$hostname'/' $NGINX_CONFIG;
  sudo service nginx reload;
  
fi

if service --status-all | grep -Fq 'mysql'; then
    printf "mysql is already installed\\n\\n"
else
  sudo apt install mariadb-server mariadb-client -y ;
  sudo systemctl status mysql; 
  sudo systemctl start mysql && sudo systemctl enable mysql;
  #sudo mysql_secure_installation;
  sudo mysql -u root -e "create database "$DATABASE_NAME"";
  sudo mysql -u root -e "GRANT ALL PRIVILEGES ON "$DATABASE_NAME".* TO '"$DATABASE_USER"'@'localhost' IDENTIFIED BY '"$DATABASE_PASSWORD"'";
fi

## installing php ##
if service --status-all | grep -Fq 'php7.2-fpm'; then
  printf "php is already installed\\n\\n"
else
  sudo apt install php7.2 php7.2-fpm php7.2-mysql php-common php7.2-cli php7.2-common php7.2-opcache php7.2-readline php7.2-xml php7.2-gd \
    php-imagick  php7.2-gd php7.2-json php7.2-curl  php7.2-zip php7.2-xml \
    php7.2-mbstring php7.2-bz2 php7.2-intl -y;
    
  sudo systemctl start php7.2-fpm;
  sudo systemctl enable php7.2-fpm;
  systemctl status php7.2-fpm;
fi

if [ -d $INSTALLATION_DIR ]; then
    printf "Nextcloud is already installed\\n\\n"
  # Control will enter here if $DIRECTORY exists.
else
    ## installing nextcloud ##
    wget https://download.nextcloud.com/server/releases/nextcloud-16.0.0.zip
    sudo apt install unzip
    sudo unzip nextcloud-16.0.0.zip -d /usr/share/nginx/
    sudo chown www-data:www-data $INSTALLATION_DIR -R
fi

