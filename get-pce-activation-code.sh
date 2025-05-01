#get-pce-activation-code.sh
yum install -y jq
#port=$(cat /etc/illumio-pce/runtime_env.yml | grep front_end_https_port | cut -d' ' -f2)
basic_auth_token=$(echo -n "$pce_admin_username_email_address:$pce_admin_password"|base64 --wrap=0)
auth_token=$(curl -X POST -H "Authorization: Basic $basic_auth_token" https://$fqdn:$port/api/v2/login_users/authenticate?pce_fqdn=$fqdn | jq -r '.auth_token')
login_response=$(curl -H "Authorization: Token token=$auth_token" https://$(hostname):$port/api/v2/users/login)
auth_username=$(echo $login_response | jq -r '.auth_username')
session_token=$(echo $login_response | jq -r '.session_token')
#get activation code
activation_code=$(curl -u $auth_username:$session_token https://$fqdn:$port/api/v2/orgs/1/pairing_profiles/1/pairing_key -X POST -H 'content-type: application/json' --data-raw '{}' | jq -r .activation_code)
export activation_code