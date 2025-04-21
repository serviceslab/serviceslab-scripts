#create-aws-a-record.sh
yum install -y jq
cat << EEOF >> /etc/rc.local
#get zone id from hostname
/usr/local/bin/aws route53 list-hosted-zones | jq -r '.HostedZones[]|select(.Name=="$domain.") | .Id' | cut -d/ -f3 > /.hostedzone
#create batch file
cat << EOF > /.create_a_record.json
{
"Changes": [{
"Action": "UPSERT",
"ResourceRecordSet": {
"Name": "\$(hostname).",
"Type": "A",
"TTL": 300,
"ResourceRecords": [{ "Value": "\$(hostname -I)"}]
}}]
}
EOF
#create a record
/usr/local/bin/aws route53 change-resource-record-sets --hosted-zone-id \$(cat /.hostedzone) --change-batch file:///.create_a_record.json
EEOF
chmod +x /etc/rc.local
