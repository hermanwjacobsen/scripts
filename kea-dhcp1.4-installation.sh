#!/bin/bash

#Kea

kea_interface=ens160

# Database Variables

db_name=keadb
db_user=keauser
db_pass=ChangeThisPassword
kea_config_dhcp4="/etc/kea/kea-dhcp4.conf"
kea_config_dhcp6="/etc/kea/kea-dhcp6.conf"
kea_dhcp_interface="ens160"

# Installation Variables

downloads=/downloads
keaftp=http://ftp.isc.org/isc/kea/1.4.0
keafile=kea-1.4.0.tar.gz
keafolder=kea-1.4.0

# Script

ping ftp.isc.org -c 1

if [ ! -d "$downloads" ]; then
        mkdir $downloads
fi
cd $downloads

wget $keaftp/$keafile -O $keafile
if [[ $? -ne 0 ]]; then
    echo "wget failed"
    exit 1;
fi

if [ -f "$keafile" ]; then
        tar -xf $keafile kea-1.4.0
fi

apt-get install -y \
mysql-client libmysqlclient-dev build-essential libboost-all-dev liblog4cplus-dev libbotan-1.10-1 \
perl python automake libtool pkg-config openssl libssl-dev flex dhcpdump mysql-server


if [ ! -d "$keafolder" ]; then
        mkdir $keafolder
        tar -zxvf $keafile -C $keafolder
else
        tar -zxvf $keafile -C $keafolder
fi

cd $keafolder
./configure --with-mysql --sysconfdir=/etc
make
make install

if ! grep -q "LD_LIBRARY_PATH" /etc/environment
then
        echo LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib" >> /etc/environment
fi
if ! grep -q "LD_LIBRARY_PATH" /etc/environment
then
        echo export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib" >> ~/.bashrc
fi

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib"

echo ""
echo "##########################################"
echo "#   Enter Password For Mysql Root User   #"
echo "##########################################"
echo ""

mysql -u root -p <<MYSQL_SCRIPT
DROP DATABASE IF EXISTS $db_name;
DROP USER IF EXISTS '$db_user'@'localhost';
CREATE DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

kea-admin lease-init mysql -u $db_user -p $db_pass -n $db_name
kea-admin lease-upgrade mysql -u $db_user -p $db_pass -n $db_name
kea-admin lease-version mysql -u $db_user -p $db_pass -n $db_name





if [ -f $kea_config_dhcp4 ]; then
        mv $kea_config_dhcp4 $kea_config_dhcp4.old
fi
if [ -f $kea_config_dhcp6 ]; then
        mv $kea_config_dhcp6 $kea_config_dhcp6.old
fi

cat > $kea_config_dhcp4 <<EOL
{
"Dhcp4": {
    "interfaces-config": {
        "interfaces": [ "$kea_dhcp_interface" ]
    },
    "host-reservation-identifiers": [ "circuit-id", "hw-address", "duid", "client-id" ],
    "control-socket": {
        "socket-type": "unix",
        "socket-name": "/tmp/kea-dhcp4-ctrl.sock"
    },
    "valid-lifetime": 900,


   "lease-database": {
         "type": "mysql",
         "name": "$db_name",
         "user": "$db_user",
         "password": "$db_pass",
         "host": "localhost",
         "port": 3306
    },

   "hosts-database": {
         "type": "mysql",
         "name": "$db_name",
         "user": "$db_user",
         "password": "$db_pass",
         "host": "localhost",
         "port": 3306
    }
},

"Logging":
{
"loggers": [
    {
        "name": "kea-dhcp4",
        "output_options": [
            {
               "output": "/var/log/kea/dhcp4.log"
            }
        ],
        "severity": "INFO",
        "debuglevel": 0
    }
  ]
}

}
EOL


cat > $kea_config_dhcp6 <<EOL
{
"Dhcp6": {
    "interfaces-config": {
        "interfaces": [ "$kea_dhcp_interface" ]
    },

    "renew-timer": 1000,
    "rebind-timer": 2000,
    "preferred-lifetime": 3000,
    "valid-lifetime": 4000,

    "control-socket": {
        "socket-type": "unix",
        "socket-name": "/tmp/kea-dhcp6-ctrl.sock"
    },

    "lease-database": {
        "type": "memfile",
        "lfc-interval": 3600
    },

    "hosts-database": {
         "type": "mysql",
         "name": "$db_name",
         "user": "$db_user",
         "password": "$db_pass",
         "host": "localhost",
         "port": 3306
    },
    "expired-leases-processing": {
        "reclaim-timer-wait-time": 10,
        "flush-reclaimed-timer-wait-time": 25,
        "hold-reclaimed-time": 3600,
        "max-reclaim-leases": 100,
        "max-reclaim-time": 250,
        "unwarned-reclaim-cycles": 5
    }

},

"Logging":
{
  "loggers": [
    {
        "name": "kea-dhcp6",
        "output_options": [
            {
               "output": "/var/log/kea/dhcp6.log"
            }
        ],
        "severity": "INFO",
        "debuglevel": 0
    }
  ]
}

}
EOL


cat > /etc/systemd/system/kea-dhcp4.service <<EOL
[Unit]
Description= Kea DHCPv4 Server
Wants=network-online.target
After=network-online.target
After=time-sync.target
Wants=mysql.service
Requires=mysql.service

[Service]
EnvironmentFile=/etc/environment
ExecStart=/usr/local/sbin/kea-dhcp4 -c /etc/kea/kea-dhcp4.conf

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/kea-dhcp6.service <<EOL

[Unit]
Description= Kea DHCPv6 Server
Wants=network-online.target
After=network-online.target
After=time-sync.target
Wants=mysql.service
Requires=mysql.service


[Service]
EnvironmentFile=/etc/environment
ExecStart=/usr/local/sbin/kea-dhcp6 -c /etc/kea/kea-dhcp6.conf

[Install]
WantedBy=multi-user.target
EOL

systemctl enable mysql.service
systemctl enable kea-dhcp4.service
systemctl enable kea-dhcp6.service