#######################################################################################################################
# All IP, Username And Password in this template are in a test enviroment, and are not used in any pruduction network # 
#######################################################################################################################

apt update
add-apt-repository universe
apt install -y ruby ruby-dev libsqlite3-dev libssl-dev pkg-config cmake libssh2-1-dev net-tools tree libicu-dev zlib1g-dev g++ libmysqlclient-dev mysql-server

gem install oxidized
gem install oxidized-script oxidized-web sequel mysql2
useradd oxidized
chsh -s /usr/sbin/nologin oxidized
mkdir -p /opt/oxidized/{output,.config/oxidized/}
usermod -m -d /opt/oxidized oxidized
sudo chown -R oxidized:oxidized /opt/oxidized
echo "OXIDIZED_HOME=/opt/oxidized" | sudo tee --append /etc/environment
mkdir /var/lib/oxidized
chown oxidized:oxidized /var/lib/oxidized


cat <<EOF> /opt/oxidized/.config/oxidized/config
# /opt/oxidized/.config/oxidized/config
---
username: username
password: password
model: cisco
interval: 60
use_syslog: true
log: /opt/oxidized/.config/oxidized/logs/
debug: false
rest: false
threads: 30
timeout: 20
retries: 3
prompt: !ruby/regexp /^([\w.@-]+[#>]\s?)$/
next_adds_job: false
pid: "/opt/oxidized/pid"

rest: 0.0.0.0:8888

vars: 
  remove_secret: true


input:
  default: ssh
  debug: false
  ssh:
    secure: false

output:
  default: git
  git:
    user: Oxidized
    email: Oxidized@local.local
    repo: "/var/lib/oxidized/git-repos/default.git"


source:
  default: sql
  sql:
    adapter: mysql2
    database: oxidized
    table: nodes
    user: oxidized
    password: oxipw
    query: "SELECT * FROM nodes WHERE n_enabled = True"
    map:
      name: n_name
      ip: n_ip
      model: n_model
      group: n_group
      username: n_username
      password: n_password



model_map:
  juniper: junos
  cisco: ios



groups:
  juniper:
    username: root1
    password: Password0.2020
  cisco:
    username: root1
    password: Password0.2020

models: {}
EOF

cat <<EOF> /opt/oxidized/.config/oxidized/router.db
# /opt/oxidized/.config/oxidized/router.db
# name:ip:model:group
ios1:192.168.1.1:cisco:cisco
EOF

sudo chown -R oxidized:oxidized /opt/oxidized



cat <<EOF> /lib/systemd/system/oxidized.service
# /lib/systemd/system/oxidized.service
[Unit]
Description=Oxidized - Network Device Configuration Backup Tool
After=network-online.target multi-user.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/oxidized
User=oxidized
KillSignal=SIGKILL

[Install]
WantedBy=multi-user.target
EOF

echo "KexAlgorithms diffie-hellman-group1-sha1,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1" >> /etc/ssh/ssh_config



systemctl start oxidized.service
systemctl enable oxidized.service

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/oxidized.key -out /etc/nginx/ssl/oxidized.crt

apt-get install nginx nginx-extras apache2-utils
rm /etc/nginx/sites-enabled/default

cat <<EOF> /etc/nginx/sites-enabled/oxidized
server {
       listen         80;
       server_name oxidized.wjacobsen.lab;
       return         301 https://$server_name$request_uri;
}


server {

        listen 443 ssl;

        ssl_certificate /etc/nginx/ssl/oxidized.crt;
        ssl_certificate_key /etc/nginx/ssl/oxidized.key;

        server_name oxidized.example.com;

        # add Strict-Transport-Security to prevent man in the middle attacks
        add_header Strict-Transport-Security "max-age=31536000";


        location / {
                proxy_pass http://127.0.0.1:8888/;
        }

        access_log /var/log/nginx/access_oxidized.log;
        error_log /var/log/nginx/error_oxidized.log;
}
EOF

mkdir /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/oxidized.key -out /etc/nginx/ssl/oxidized.crt

systemctl reload nginx

# Basic Authentication
#add auth_basic and auth_basic_userfile under location / for port 443 in /etc/nginx/sites-enabled/oxidized
#
##        location / {
##                auth_basic "Administrator’s Area";
##                auth_basic_user_file /etc/nginx/.oxidized-htpasswd;
##                proxy_pass http://127.0.0.1:8888/;
##
##        }
#
# Create htpasswd file and first user
#
## htpasswd -c /etc/nginx/.oxidized-htpasswd user1
#
# Create Second User
#
## htpasswd /etc/nginx/.oxidized-htpasswd user2
#
# Restar Service
#
## service nginx restart


mysql -p <<EOF
drop database oxidized;
CREATE DATABASE oxidized CHARACTER SET utf8 COLLATE utf8_general_ci;
use oxidized;
CREATE TABLE nodes (
id INT(10) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
n_name text NOT NULL,
n_ip text NOT NULL,
n_model text NOT NULL,
n_group text NOT NULL,
n_username text NOT NULL,
n_password text NOT NULL,
n_enabled boolean NOT NULL,
n_location text,
n_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
n_last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
insert into nodes (n_name,n_ip,n_model,n_group,n_username,n_password,n_enabled,n_location) VALUEs ('Cisco-Hostname','192.168.1.1','cisco','cisco','username','password',True,'location (Remove/Edit this row');
CREATE USER 'oxidized'@'localhost' IDENTIFIED BY 'oxipw';
GRANT ALL PRIVILEGES ON oxidized.* TO 'oxidized'@'localhost';
FLUSH PRIVILEGES;
EOF






