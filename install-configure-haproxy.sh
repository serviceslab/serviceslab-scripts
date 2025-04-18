#install-configure-haproxy.sh
yum install -y haproxy
systemctl enable haproxy
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.original
cat << EOF > /etc/haproxy/haproxy.cfg
frontend proxy
    bind *:$frontend_port
    mode tcp
    default_backend pce
backend pce
    server localhost *:$port check
    mode tcp
EOF
systemctl restart haproxy
