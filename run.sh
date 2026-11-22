cd serveur-apache
sudo ./deploy.sh

cd ../serveur-tomcat
sudo ./deploy.sh

cd ..
sudo haproxy -c -f haproxy.cfg
sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo systemctl enable haproxy