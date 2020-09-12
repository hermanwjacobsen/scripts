## Script not finished so you will need to do some manual changes
##
## use find, and change some values
## Change $NET_ADAPTER and 192.168.21 to what your settings
##
## ignore this warning // warning: taking address of packed member of ‘snort::SfIp’ may result in an unaligned pointer value
read -p "Enter Network Adapter: " NET_ADAPTER
read -p "Enter Internal Network: " HOME_NET

apt update && apt upgrade -y
apt install build-essential libpcap-dev libpcre3-dev libnet1-dev zlib1g-dev luajit hwloc libdnet-dev libdumbnet-dev bison flex liblzma-dev openssl libssl-dev pkg-config libhwloc-dev cmake cpputest libsqlite3-dev uuid-dev libcmocka-dev libnetfilter-queue-dev libmnl-dev autotools-dev libluajit-5.1-dev libunwind-dev gettext net-tools -y 
mkdir /downloads
cd /downloads
mkdir -p /downloads/snort-source-files && cd /downloads/snort-source-files
git clone https://github.com/snort3/libdaq.git
cd libdaq
./bootstrap
./configure
make && make install
cd /downloads
wget wget https://github.com/gperftools/gperftools/releases/download/gperftools-2.8/gperftools-2.8.tar.gz
tar xzf gperftools-2.8.tar.gz
cd gperftools-2.8/
./configure
make && make install
cd /downloads
git clone git://github.com/snortadmin/snort3.git
cd snort3
./configure_cmake.sh --prefix=/usr/local --enable-tcmalloc
cd build
make && make install
ldconfig
snort -V



ip link set dev $NET_ADAPTER promisc on
ip add sh $NET_ADAPTER
ethtool -K $NET_ADAPTER gro off
ethtool -K $NET_ADAPTER lro off
ethtool -k $NET_ADAPTER | grep receive-offload

cat <<EOF> /etc/systemd/system/snort3-nic.service
[Unit]
Description=Set Snort 3 NIC in promiscuous mode and Disable GRO, LRO on boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip link set dev $NET_ADAPTER promisc on
ExecStart=/usr/sbin/ethtool -K enp0s8 gro off
ExecStart=/usr/sbin/ethtool -K enp0s8 lro off
TimeoutStartSec=0
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload

mkdir /usr/local/etc/rules

cd /downloads
wget https://www.snort.org/downloads/community/snort3-community-rules.tar.gz
tar xzf snort3-community-rules.tar.gz -C /usr/local/etc/rules/
ls /usr/local/etc/rules/snort3-community-rules/

#sed -i 's/HOME_NET = .*/HOME_NET = '\''192.168.21.0\/24'\''/' /usr/local/etc/snort/snort.lua
#sed -i 's/EXTERNAL_NET = .*/EXTERNAL_NET = '\''!$HOME_NET'\''/' /usr/local/etc/snort/snort.lua

cat <<EOF> /usr/local/etc/snort/snort.lua
---------------------------------------------------------------------------
-- Snort++ configuration
---------------------------------------------------------------------------

-- there are over 200 modules available to tune your policy.
-- many can be used with defaults w/o any explicit configuration.
-- use this conf as a template for your specific configuration.

-- 1. configure defaults
-- 2. configure inspection
-- 3. configure bindings
-- 4. configure performance
-- 5. configure detection
-- 6. configure filters
-- 7. configure outputs
-- 8. configure tweaks

---------------------------------------------------------------------------
-- 1. configure defaults
---------------------------------------------------------------------------

-- HOME_NET and EXTERNAL_NET must be set now
-- setup the network addresses you are protecting
HOME_NET = '$HOME_NET'

-- set up the external network addresses.
-- (leave as "any" in most situations)
EXTERNAL_NET = '!\$HOME_NET'

include 'snort_defaults.lua'
include 'file_magic.lua'

---------------------------------------------------------------------------
-- 2. configure inspection
---------------------------------------------------------------------------

-- mod = { } uses internal defaults
-- you can see them with snort --help-module mod

-- mod = default_mod uses external defaults
-- you can see them in snort_defaults.lua

-- the following are quite capable with defaults:

stream = { }
stream_ip = { }
stream_icmp = { }
stream_tcp = { }
stream_udp = { }
stream_user = { }
stream_file = { }

arp_spoof = { }
back_orifice = { }
dnp3 = { }
dns = { }
http_inspect = { }
http2_inspect = { }
imap = { }
modbus = { }
normalizer = { }
pop = { }
rpc_decode = { }
sip = { }
ssh = { }
ssl = { }
telnet = { }

dce_smb = { }
dce_tcp = { }
dce_udp = { }
dce_http_proxy = { }
dce_http_server = { }

-- see snort_defaults.lua for default_*
gtp_inspect = default_gtp
port_scan = default_med_port_scan
smtp = default_smtp

ftp_server = default_ftp_server
ftp_client = { }
ftp_data = { }

-- see file_magic.lua for file id rules
file_id = { file_rules = file_magic }

-- the following require additional configuration to be fully effective:

appid =
{
    -- appid requires this to use appids in rules
    --app_detector_dir = 'directory to load appid detectors from'
    app_detector_dir = '/usr/local/lib',
    log_stats = true,
}

--[[
reputation =
{
    -- configure one or both of these, then uncomment reputation
    --blacklist = 'blacklist file name with ip lists'
    --whitelist = 'whitelist file name with ip lists'
}
--]]

---------------------------------------------------------------------------
-- 3. configure bindings
---------------------------------------------------------------------------

wizard = default_wizard

binder =
{
    -- port bindings required for protocols without wizard support
    { when = { proto = 'udp', ports = '53', role='server' },  use = { type = 'dns' } },
    { when = { proto = 'tcp', ports = '53', role='server' },  use = { type = 'dns' } },
    { when = { proto = 'tcp', ports = '111', role='server' }, use = { type = 'rpc_decode' } },
    { when = { proto = 'tcp', ports = '502', role='server' }, use = { type = 'modbus' } },
    { when = { proto = 'tcp', ports = '2123 2152 3386', role='server' }, use = { type = 'gtp_inspect' } },

    { when = { proto = 'tcp', service = 'dcerpc' }, use = { type = 'dce_tcp' } },
    { when = { proto = 'udp', service = 'dcerpc' }, use = { type = 'dce_udp' } },

    { when = { service = 'netbios-ssn' },      use = { type = 'dce_smb' } },
    { when = { service = 'dce_http_server' },  use = { type = 'dce_http_server' } },
    { when = { service = 'dce_http_proxy' },   use = { type = 'dce_http_proxy' } },

    { when = { service = 'dnp3' },             use = { type = 'dnp3' } },
    { when = { service = 'dns' },              use = { type = 'dns' } },
    { when = { service = 'ftp' },              use = { type = 'ftp_server' } },
    { when = { service = 'ftp-data' },         use = { type = 'ftp_data' } },
    { when = { service = 'gtp' },              use = { type = 'gtp_inspect' } },
    { when = { service = 'imap' },             use = { type = 'imap' } },
    { when = { service = 'http' },             use = { type = 'http_inspect' } },
    { when = { service = 'http2' },            use = { type = 'http2_inspect' } },
    { when = { service = 'modbus' },           use = { type = 'modbus' } },
    { when = { service = 'pop3' },             use = { type = 'pop' } },
    { when = { service = 'ssh' },              use = { type = 'ssh' } },
    { when = { service = 'sip' },              use = { type = 'sip' } },
    { when = { service = 'smtp' },             use = { type = 'smtp' } },
    { when = { service = 'ssl' },              use = { type = 'ssl' } },
    { when = { service = 'sunrpc' },           use = { type = 'rpc_decode' } },
    { when = { service = 'telnet' },           use = { type = 'telnet' } },

    { use = { type = 'wizard' } }
}

---------------------------------------------------------------------------
-- 4. configure performance
---------------------------------------------------------------------------

-- use latency to monitor / enforce packet and rule thresholds
--latency = { }

-- use these to capture perf data for analysis and tuning
--profiler = { }
--perf_monitor = { }

---------------------------------------------------------------------------
-- 5. configure detection
---------------------------------------------------------------------------

references = default_references
classifications = default_classifications

ips =
{
    -- use this to enable decoder and inspector alerts
    --enable_builtin_rules = true,

    -- use include for rules files; be sure to set your path
    -- note that rules files can include other rules files
    include = '/usr/local/etc/rules/snort3-community-rules/snort3-community.rules'
}

rewrite = { }

-- use these to configure additional rule actions
-- react = { }
-- reject = { }

-- use this to enable payload injection utility
-- payload_injector = { }

---------------------------------------------------------------------------
-- 6. configure filters
---------------------------------------------------------------------------

-- below are examples of filters
-- each table is a list of records

--[[
suppress =
{
    -- don't want to any of see these
    { gid = 1, sid = 1 },

    -- don't want to see these for a given server
    { gid = 1, sid = 2, track = 'by_dst', ip = '1.2.3.4' },
}
--]]

--[[
event_filter =
{
    -- reduce the number of events logged for some rules
    { gid = 1, sid = 1, type = 'limit', track = 'by_src', count = 2, seconds = 10 },
    { gid = 1, sid = 2, type = 'both',  track = 'by_dst', count = 5, seconds = 60 },
}
--]]

--[[
rate_filter =
{
    -- alert on connection attempts from clients in SOME_NET
    { gid = 135, sid = 1, track = 'by_src', count = 5, seconds = 1,
      new_action = 'alert', timeout = 4, apply_to = '[$SOME_NET]' },

    -- alert on connections to servers over threshold
    { gid = 135, sid = 2, track = 'by_dst', count = 29, seconds = 3,
      new_action = 'alert', timeout = 1 },
}
--]]

---------------------------------------------------------------------------
-- 7. configure outputs
---------------------------------------------------------------------------

-- event logging
-- you can enable with defaults from the command line with -A <alert_type>
-- uncomment below to set non-default configs
--alert_csv = { }
--alert_full = { }
--alert_sfsocket = { }
--alert_syslog = { }
--unified2 = { }
alert_fast = {
        file = true,
        packet = false,
        limit = 10,
}
-- packet logging
-- you can enable with defaults from the command line with -L <log_type>
--log_codecs = { }
--log_hext = { }
--log_pcap = { }

-- additional logs
--packet_capture = { }
--file_log = { }

---------------------------------------------------------------------------
-- 8. configure tweaks
---------------------------------------------------------------------------

if ( tweaks ~= nil ) then
    include(tweaks .. '.lua')
end
EOF

wget https://www.snort.org/downloads/openappid/14733 -O OpenAppID-14733.tgz
tar -zxvf OpenAppID-14733.tgz

cp -R odp/ /usr/local/lib/
mkdir /var/log/snort

cat <<EOF> /usr/local/etc/rules/local.rules
alert icmp any any -> $HOME_NET any (msg:"ICMP connection test"; sid:1000001; rev:1;)
EOF


snort -c /usr/local/etc/snort/snort.lua -R /usr/local/etc/rules/local.rules

useradd -r -s /usr/sbin/nologin -M -c SNORT_IDS snort
chmod -R 5775 /var/log/snort
chown -R snort:snort /var/log/snort

cat <<EOF> /etc/systemd/system/snort3.service
[Unit]
Description=Snort 3 NIDS Daemon
After=syslog.target network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/snort -c /usr/local/etc/snort/snort.lua -s 65535 -k none -l /var/log/snort -D -i $NET_ADAPTER -m 0x1b -u snort -g snort

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload


systemctl enable --now snort3
systemctl status snort3





