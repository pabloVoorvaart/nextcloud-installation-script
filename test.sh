DATABASE_NAME = "nextcloud"
DATABASE_USER = "admin"
DATABASE_PASSWORD = "dwadawdwdadw"
INSTALLATION_DIR = "/usr/share/nginx/nextcloud/"
NGINX_CONFIG = "/etc/nginx/conf.d/nextcloud"

sudo mysql -u root -e "create database "$DATABASE_NAME""
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON "$DATABASE_NAME".* TO '"$DATABASE_USER"'@'localhost' IDENTIFIED BY '"$DATABASE_PASSWORD"'";
