#install-pce.sh
yum install -y wget bzip2 net-tools initscripts libxcrypt-compat compat-openssl11 glibc-langpack-en
localectl set-locale LANG=en_US.utf8

rpm -Uvh /illumio-pce-*.rpm
#mkdir /opt/illumio-pce/ && tar -xf illumio-pce-*.tgz -C /opt/illumio-pce/ && chown -R root:ilo-pce /opt/illumio-pce/

#file kernal settings

echo y|cp /etc/letsencrypt/live/$(hostname)/cert.pem /var/lib/illumio-pce/cert/server.crt
echo y|cp /etc/letsencrypt/live/$(hostname)/privkey.pem /var/lib/illumio-pce/cert/server.key
chmod 400 /var/lib/illumio-pce/cert/server.key
chown ilo-pce:ilo-pce /var/lib/illumio-pce/cert/server.key

/opt/illumio-pce/illumio-pce-env setup --batch node_type='snc0' email_address=$pce_admin_username_email_address pce_fqdn=$(hostname) metrics_collection_enabled=false expose_user_invitation_link=true front_end_https_port=$port front_end_event_service_port=$((port+1))
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl start --runlevel 1 &> /dev/null
sleep 60
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status -w
sleep 10
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status -w
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-db-management setup
sleep 10
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl set-runlevel 5 &> /dev/null
sleep 60
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status -w
sleep 10
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status -w
#create domain
sudo --preserve-env -u ilo-pce ILO_PASSWORD=$pce_admin_password /opt/illumio-pce/illumio-pce-db-management create-domain --user-name $pce_admin_username_email_address --full-name admin --org-name $(hostname)
#get latest ven bundle
latest_illumio_ven_bundle=$(ls /illumio-ven-bundle-*|tail -n 1)
#install ven bundle
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl ven-software-install $latest_illumio_ven_bundle --compatibility-matrix /illumio-release-compatibility-* --default --no-prompt --orgs 1
illumio_ven_bundles=($(ls /illumio-ven-bundle-*))
for illumio_ven_bundle in "${illumio_ven_bundles[@]}"; do
 if [[ $illumio_ven_bundle == $latest_illumio_ven_bundle ]]; then continue; fi
 sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl ven-software-install $illumio_ven_bundle --compatibility-matrix /illumio-release-compatibility-* --no-prompt --orgs 1
done
#sleep 10 && systemctl restart sshd &
#pkill sshd &
#install nginx
yum install nginx -y
systemctl enable nginx
systemctl start nginx
