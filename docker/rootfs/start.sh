#!/bin/bash

######### functions

_maxUploadSize() {
    echo "[i] Setting uploadsize to ${MAX_UPLOAD_SIZE}M"
	
	sed -i "/post_max_size/c\\post_max_size=${MAX_UPLOAD_SIZE}M" /etc/php82/php.ini
	sed -i "/upload_max_filesize/c\\upload_max_filesize=${MAX_UPLOAD_SIZE}M" /etc/php82/php.ini

    # set error reporting no notices, no warnings
    sed -i "/^error_reporting/c\\error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_WARNING & ~E_NOTICE" /etc/php82/php.ini
    
	sed -i -e "s/50M/${MAX_UPLOAD_SIZE}M/g" /etc/nginx/http.d/default.conf

    MAX_RAM=$((MAX_UPLOAD_SIZE + 30)) # 30megs more than the upload size
    echo "[i] Also changing memory limit of PHP to ${MAX_RAM}M"
    sed -i -e "s/128M/${MAX_RAM}M/g" /etc/php82/php.ini
	sed -i "/memory_limit/c\\memory_limit=${MAX_RAM}M" /etc/php82/php.ini
}

_filePermissions() {
    chown -R nginx:nginx /var/www
    touch data/sha1.csv
    chown nginx:nginx data/sha1.csv
}

# NUEVA FUNCIÓN - COPIA EL EXAMPLE PRIMERO
_copyExampleConfig() {
    echo "[+] Checking config.inc.php..."
    if [ ! -f "inc/config.inc.php" ]; then
        echo "[+] Copying example.config.inc.php to config.inc.php"
        cp inc/example.config.inc.php inc/config.inc.php
        chown nginx:nginx inc/config.inc.php
        echo "[+] ✅ Config created from example"
    else
        echo "[+] Config already exists, skipping copy"
    fi
}

_buildConfig() {
    echo "[+] Building config from environment variables..."
    
    # Solo genera si el archivo no existe O si URL está definida
    if [ ! -f "inc/config.inc.php" ] || [ ! -z "${URL:-}" ]; then
        echo "<?php" > inc/config.inc.php
        echo "define('URL', '${URL:-}');" >> inc/config.inc.php
        echo "define('TITLE', '${TITLE:-PictShare}');" >> inc/config.inc.php
        echo "define('ALLOWED_SUBNET', '${ALLOWED_SUBNET:-}');" >> inc/config.inc.php
        echo "define('CONTENTCONTROLLERS', '${CONTENTCONTROLLERS:-}');" >> inc/config.inc.php
        echo "define('MASTER_DELETE_CODE', '${MASTER_DELETE_CODE:-}');" >> inc/config.inc.php
        echo "define('MASTER_DELETE_IP', '${MASTER_DELETE_IP:-}');" >> inc/config.inc.php
        echo "define('UPLOAD_FORM_LOCATION', '${UPLOAD_FORM_LOCATION:-}');" >> inc/config.inc.php
        echo "define('UPLOAD_CODE', '${UPLOAD_CODE:-}');" >> inc/config.inc.php
        echo "define('LOG_UPLOADER', ${LOG_UPLOADER:-false});" >> inc/config.inc.php
        echo "define('MAX_RESIZED_IMAGES',${MAX_RESIZED_IMAGES:--1});" >> inc/config.inc.php
        echo "define('ALLOW_BLOATING', ${ALLOW_BLOATING:-false});" >> inc/config.inc.php
        echo "define('SHOW_ERRORS', ${SHOW_ERRORS:-false});" >> inc/config.inc.php
        echo "define('JPEG_COMPRESSION', ${JPEG_COMPRESSION:-90});" >> inc/config.inc.php
        echo "define('PNG_COMPRESSION', ${PNG_COMPRESSION:-6});" >> inc/config.inc.php
        echo "define('ALT_FOLDER', '${ALT_FOLDER:-}');" >> inc/config.inc.php
        echo "define('S3_BUCKET', '${S3_BUCKET:-}');" >> inc/config.inc.php
        echo "define('S3_ACCESS_KEY', '${S3_ACCESS_KEY:-}');" >> inc/config.inc.php
        echo "define('S3_SECRET_KEY', '${S3_SECRET_KEY:-}');" >> inc/config.inc.php
        echo "define('S3_ENDPOINT', '${S3_ENDPOINT:-}');" >> inc/config.inc.php
        echo "define('S3_REGION', '${S3_REGION:-}');" >> inc/config.inc.php
        echo "define('FTP_SERVER', '${FTP_SERVER:-}');" >> inc/config.inc.php
        echo "define('FTP_PORT', ${FTP_PORT:-21});" >> inc/config.inc.php
        echo "define('FTP_USER', '${FTP_USER:-}');" >> inc/config.inc.php
        echo "define('FTP_PASS', '${FTP_PASS:-}');" >> inc/config.inc.php
        echo "define('FTP_PASSIVEMODE', ${FTP_PASSIVEMODE:-true});" >> inc/config.inc.php
        echo "define('FTP_SSL', ${FTP_SSL:-false});" >> inc/config.inc.php
        echo "define('FTP_BASEDIR', '${FTP_BASEDIR:-}');" >> inc/config.inc.php
        echo "define('ENCRYPTION_KEY', '${ENCRYPTION_KEY:-}');" >> inc/config.inc.php
        echo "define('FFMPEG_BINARY', '${FFMPEG_BINARY:-/usr/bin/ffmpeg}');" >> inc/config.inc.php
        echo "define('ALWAYS_WEBP', ${ALWAYS_WEBP:-false});" >> inc/config.inc.php
        echo "define('ALLOWED_DOMAINS', '${ALLOWED_DOMAINS:-}');" >> inc/config.inc.php
        echo "define('SPLIT_DATA_DIR', ${SPLIT_DATA_DIR:-false});" >> inc/config.inc.php
        chown nginx:nginx inc/config.inc.php
        echo "[+] ✅ Config built from environment variables"
    else
        echo "[+] Skipping config build (file exists and no URL env var)"
    fi
}

######### main

echo 'Starting Pictshare'

cd /var/www/

# PRIMERO COPIA EL EXAMPLE CONFIG
_copyExampleConfig

if [[ ${MAX_UPLOAD_SIZE:=100} =~ ^[0-9]+$ ]]; then
        _maxUploadSize
fi

# run _filePermissions function unless SKIP_FILEPERMISSIONS is set to true
if [[ ${SKIP_FILEPERMISSIONS:=false} != true ]]; then
        _filePermissions
fi

# DESPUÉS APLICA LAS VARIABLES DE ENTORNO (si las hay)
_buildConfig

echo ' [+] Starting php'
php-fpm82

echo ' [+] Starting nginx'

mkdir -p /var/log/nginx/pictshare
touch /var/log/nginx/pictshare/access.log
exec nginx -g "daemon off;"
