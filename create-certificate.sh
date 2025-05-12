#create-certificate.sh
#create certbot_authenticator.sh
cat << EOFa > /.certbot_authenticator.sh
cat << EOF > /.create_txt_record.json
{
"Changes": [{
"Action": "CREATE",
"ResourceRecordSet": {
"Name": "_acme-challenge.\$CERTBOT_DOMAIN.",
"Type": "TXT",
"TTL": 300,
"ResourceRecords": [{ "Value": "\"\$CERTBOT_VALIDATION\""}]
}}]
}
EOF
sleep 3
/usr/local/bin/aws route53 change-resource-record-sets --hosted-zone-id \$(cat /.hostedzone) --change-batch file:///.create_txt_record.json
sleep 20
EOFa
chmod +x /.certbot_authenticator.sh
#create certbot_cleanup.sh
cat << EOFb > /.certbot_cleanup.sh
cat << EOF > /.delete_txt_record.json
{
"Changes": [{
"Action": "DELETE",
"ResourceRecordSet": {
"Name": "_acme-challenge.\$CERTBOT_DOMAIN.",
"Type": "TXT",
"TTL": 300,
"ResourceRecords": [{ "Value": "\"\$CERTBOT_VALIDATION\""}]
}}]
}
EOF
sleep 3
/usr/local/bin/aws route53 change-resource-record-sets --hosted-zone-id \$(cat /.hostedzone) --change-batch file:///.delete_txt_record.json
EOFb
chmod +x /.certbot_cleanup.sh
#install certbot
dnf install -y epel-release
dnf install -y certbot
#append create certificate commands to /etc/rc.local
cat << EOF >> /etc/rc.local
#sleep for creation of dns record on name servers
sleep 10
#create certificate
#if dev, sign with test CAs
if [[ \$(hostname) != *".dev."* ]]; then
    certbot certonly --domain \$(hostname) --manual --preferred-challenges dns --manual-auth-hook /.certbot_authenticator.sh --manual-cleanup-hook /.certbot_cleanup.sh --agree-tos --register-unsafely-without-email --keep-until-expiring --key-type rsa
else
    certbot certonly --domain \$(hostname) --manual --preferred-challenges dns --manual-auth-hook /.certbot_authenticator.sh --manual-cleanup-hook /.certbot_cleanup.sh --agree-tos --register-unsafely-without-email --keep-until-expiring --key-type rsa --test-cert
fi
certbot_result=\$(echo \$?)
#if error, sleep 60, retry
echo \$certbot_result | grep 0 || sleep 60 && certbot certonly --domain \$(hostname) --manual --preferred-challenges dns --manual-auth-hook /.certbot_authenticator.sh --manual-cleanup-hook /.certbot_cleanup.sh --agree-tos --register-unsafely-without-email --keep-until-expiring --key-type rsa --test-cert
#copy cert to pce cert
cp /etc/letsencrypt/live/$(hostname)/chain.pem /etc/pki/ca-trust/source/anchors/
update-ca-trust enable && update-ca-trust extract
echo y|cp /etc/letsencrypt/live/$(hostname)/cert.pem /var/lib/illumio-pce/cert/server.crt || true
echo y|cp /etc/letsencrypt/live/$(hostname)/privkey.pem /var/lib/illumio-pce/cert/server.key || true
chmod 400 /var/lib/illumio-pce/cert/server.key || true
chown ilo-pce:ilo-pce /var/lib/illumio-pce/cert/server.key || true
EOF
chmod +x /etc/rc.local