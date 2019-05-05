DATABASE_NAME = "nextcloud"
DATABASE_USER = "admin"
DATABASE_PASSWORD = "dwadawdwdadw"
INSTALLATION_DIR = "/usr/share/nginx/nextcloud/"
NGINX_CONFIG = "/etc/nginx/conf.d/nextcloud"

  sed -i 's/nextcloud.your-domain.com/'$hostname'/' nginx.conf;
