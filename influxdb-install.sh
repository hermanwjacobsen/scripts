echo "deb https://repos.influxdata.com/ubuntu bionic stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install influxdb
systemctl enable influxdb
systemctl start influxdb

#curl "http://localhost:8086/query" --data-urlencode "q=create database grafana"
#curl "http://localhost:8086/query" --data-urlencode "q=grant all privileges on grafana to grafana"
#curl "http://localhost:8086/query" --data-urlencode "q=CREATE USER grafana WITH PASSWORD 'grafana123' WITH ALL PRIVILEGES"

