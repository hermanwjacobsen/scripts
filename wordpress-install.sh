read -p "enter website domain: " DOMAIN
echo "# Create a new MYSQL User and database for wordpress site"
read -p "enter a database name for wp : " DATABASE
read -p "enter a username for wp mysql user: " USERNAME
read -p "enter a password for wp mysql user: " PASSWORD

apt-get update
apt-get install apache2 mysql-server mysql-client php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring php-xmlrpc php-zip php-soap php-intl php-dom php-gmagick php-simplexml php-ssh2 php-xmlreader php-date php-exif php-ftp php-iconv imagemagick php-json php-mysqli openssl libcurl4-openssl-dev libssl-dev libpcre3 libpcre3-dev php-posix php-sockets spl php-tokenizer libxml2-dev build-essential zlib1g-dev php-common php-cli php-ldap -y

mysql << EOF
CREATE DATABASE $DATABASE DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON $DATABASE.* TO '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

cat <<EOF> /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
        ServerName $DOMAIN
        ServerAlias www.$DOMAIN
        ServerAdmin webmaster@$DOMAIN
        DocumentRoot /var/www/$DOMAIN
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf
a2ensite $DOMAIN.conf

mkdir /downloads
wget -O /downloads/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xzvf /downloads/wordpress.tar.gz -C /downloads

mkdir /var/www/$DOMAIN
cp -R /downloads/wordpress/* /var/www/$DOMAIN/
sudo chown -R www-data.www-data /var/www/$DOMAIN


cat <<EOF>/var/www/$DOMAIN/wp-config.php
<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the
 * installation. You don't have to use the web site, you can
 * copy this file to "wp-config.php" and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * MySQL settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', '$DATABASE' );

/** MySQL database username */
define( 'DB_USER', '$USERNAME' );

/** MySQL database password */
define( 'DB_PASSWORD', '$PASSWORD' );

/** MySQL hostname */
define( 'DB_HOST', 'localhost' );

/** Database Charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The Database Collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
\$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', false );

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
        define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOF

for i in $(find / -name php.ini); do # Not recommended, will break on whitespace
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 512M/' $i
    sed -i 's/memory_limit =.*/memory_limit = 1024/' $i
    sed -i 's/\;max_input_var.*/max_input_var = 10000/' $i
    sed -i 's/max_execution_time =.*/max_execution_time = 300/' $i
done

service apache2 restart
service apache2 status --no-pager

