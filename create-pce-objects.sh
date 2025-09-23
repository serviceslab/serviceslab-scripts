#create-pce-objects.sh
dnf install -y jq
basic_auth_token=$(echo -n "$pce_admin_username_email_address:$pce_admin_password"|base64 --wrap=0)
auth_token=$(curl -X POST -H "Authorization: Basic $basic_auth_token" https://$(hostname):$port/api/v2/login_users/authenticate?pce_fqdn=$(hostname) | jq -r '.auth_token')
login_response=$(curl -H "Authorization: Token token=$auth_token" https://$(hostname):$port/api/v2/users/login)
auth_username=$(echo $login_response | jq -r '.auth_username')
session_token=$(echo $login_response | jq -r '.session_token')
#update default pairing profile, selective, allow labels, allow enforcement
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/pairing_profiles/1 -X PUT -H 'Content-Type: application/json' --data-raw '{"name":"default","description":"Default Pairing Profile","labels":[],"enforcement_mode":"selective","visibility_level":"flow_summary","allowed_uses_per_key":"unlimited","agent_software_release":null,"key_lifespan":"unlimited","app_label_lock":false,"env_label_lock":false,"loc_label_lock":false,"role_label_lock":false,"enforcement_mode_lock":false,"visibility_level_lock":true,"enabled":true}'
#create nginx app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-NGINX"}'
#create httpd app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-HTTPD"}'
#create opensuse app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-OPENSUSE"}'
#create suse app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-SUSE"}'
#create tomcat app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-TOMCAT"}'
#create ntp app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-NTP"}'
#create redis app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-REDIS"}'
#create mongo app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-MONGODB"}'
#create caddy app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-CADDY"}'
#create k3s app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-K3S"}'
#create container role label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"role","value":"R-CONTAINER"}'
#create share app label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"app","value":"A-SHARE"}'
#get service
service_href=$(curl -u $auth_username:$session_token "https://$(hostname):$port/api/v2/orgs/1/sec_policy/active/services?name=S-NETBIOS" | jq -r .[].href)
#create enforcement boundry
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy/draft/enforcement_boundaries -X POST -H 'Content-Type: application/json' --data-raw '{"name":"block-netbios","enabled":true,"providers":[{"actors":"ams"}],"consumers":[{"ip_list":{"href":"/orgs/1/sec_policy/draft/ip_lists/1"}}],"network_type":"brn","ingress_services":[{"href":"'$service_href'"}]}'
#provision
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy -X POST -H 'Content-Type: application/json' --data-raw '{"update_description":"","change_subset":{"enforcement_boundaries":[{"href":"/orgs/1/sec_policy/draft/enforcement_boundaries/1"}]}}'
#enable ransomware dashboard
#curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/optional_features -X PUT -H 'Content-Type: application/json' --data-raw '[{"name":"ransomware_readiness_dashboard","enabled":true}]'
#get dev label href
dev_label_href=$(curl -u $auth_username:$session_token "https://$(hostname):$port/api/v2/orgs/1/labels?key=env&value=Development" | jq -r .[].href)
#get k3s label href
k3s_label_href=$(curl -u $auth_username:$session_token "https://$(hostname):$port/api/v2/orgs/1/labels?key=app&value=A-K3S" | jq -r .[].href)
#create latest containter cluster
container_clusters_response=$(curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/container_clusters -X POST -H 'content-type: application/json' --data-raw '{"name":"k3s-latest","description":""}')
pce_container_clusters_cluster_id=$(echo $container_clusters_response | jq -r .href | cut -d/ -f5)
pce_container_clusters_cluster_token=$(echo $container_clusters_response | jq -r .container_cluster_token)
#create container pairing profile
pairing_profiles_response=$(curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/pairing_profiles -X POST -H 'content-type: application/json' --data-raw '{"name":"pp-container_nodes","description":"","labels":[{"href":"'$k3s_label_href'"},{"href":"'$dev_label_href'"}],"enforcement_mode":"visibility_only","visibility_level":"flow_summary","allowed_uses_per_key":"unlimited","agent_software_release":null,"key_lifespan":"unlimited","app_label_lock":true,"env_label_lock":true,"loc_label_lock":true,"role_label_lock":true,"enforcement_mode_lock":true,"visibility_level_lock":true,"enabled":true,"ven_type":"server"}')
pairing_profiles_response_href=$(echo $pairing_profiles_response | jq -r .href)
pairing_key_response=$(curl -u $auth_username:$session_token https://$(hostname):$port/api/v2$pairing_profiles_response_href/pairing_key -X POST -H 'content-type: application/json' --data-raw '{}')
pce_container_clusters_activation_code=$(echo $pairing_key_response | jq -r .activation_code)
#copy certificate to share for containers to pull from
echo y|cp /etc/letsencrypt/live/$(hostname)/cert.pem /usr/share/nginx/html/
echo y|cp /etc/letsencrypt/live/$(hostname)/chain.pem /usr/share/nginx/html/
echo y|cp /etc/letsencrypt/live/$(hostname)/fullchain.pem /usr/share/nginx/html/
#create containter cluster illumio-values-latest.yaml
cat << EOF > /usr/share/nginx/html/illumio-values-latest.yaml
pce_url: $(hostname):$port
cluster_id: $pce_container_clusters_cluster_id
cluster_token: $pce_container_clusters_cluster_token
cluster_code: $pce_container_clusters_activation_code
containerRuntime: k3s_containerd
containerManager: kubernetes
ignore_cert: true
clusterMode: clas
imagePullPolicy: Always
extraVolumeMounts:
  - name: root-ca
    mountPath: /etc/pki/tls/ilo_certs/
    readOnly: false
extraVolumes:
  - name: root-ca
    configMap:
      name: root-ca-config
EOF
#get container default workload profile id
container_workload_profiles=$(curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/container_clusters/$pce_container_clusters_cluster_id/container_workload_profiles)
container_workload_profiles_default_id=$(echo $container_workload_profiles | jq -r .[].href | cut -d/ -f7)
#get container label href
role_label_href=$(curl -u $auth_username:$session_token "https://$(hostname):$port/api/v2/orgs/1/labels?key=role&value=R-CONTAINER" | jq -r .[].href)
#update container workload default profile
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/container_clusters/$pce_container_clusters_cluster_id/container_workload_profiles/$container_workload_profiles_default_id -X PUT -H 'content-type: application/json' --data-raw '{"managed":true,"labels":[{"key":"env","assignment":{"href":"'$dev_label_href'"}},{"key":"role","assignment":{"href":"'$role_label_href'"}}],"enforcement_mode":"visibility_only","visibility_level":"flow_summary"}'
#remove flow collections
traffic_collector_hrefs=($(curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/settings/traffic_collector | jq -r .[].href))
for traffic_collector_href in "${traffic_collector_hrefs[@]}"; do
 curl -u $auth_username:$session_token https://$(hostname):$port/api/v2$traffic_collector_href -X DELETE
done
#enable label_based_network_detection
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/optional_features -X PUT -H 'Content-Type: application/json' --data-raw '[{"name": "label_based_network_detection","enabled": true}]'
#update password policy - 30 minutes session timeout
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/authentication_settings/password_policy -X PUT -H 'content-type: application/json' --data-raw '{"session_timeout_minutes":10}'
#enable syslog events
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/settings/syslog/destinations -X POST -H 'content-type: application/json' --data-raw '{"pce_scope":["'$(hostname)'"],"type":"local_syslog","description":"Local","audit_event_logger":{"configuration_event_included":true,"system_event_included":true,"min_severity":"informational"},"node_status_logger":{"node_status_included":true},"traffic_event_logger":{"traffic_flow_allowed_event_included":true,"traffic_flow_potentially_blocked_event_included":true,"traffic_flow_blocked_event_included":true}}'
#create flex label, key os
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/label_dimensions -X POST -H 'content-type: application/json' --data-raw '{"key":"os","display_name":"OS","display_info":{"background_color":"#818286","icon":"","foreground_color":"#ffffff","initial":"O","display_name_plural":"O","sort_ordinal":6000000}}'
#create linux os label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"os","value":"O-LINUX"}'
#create windows os label
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/labels -H 'Content-Type: application/json' --data-raw '{"key":"os","value":"O-WINDOWS"}'
#core services detection
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/settings/core_services -X PUT -H 'content-type: application/json' --data-raw '{"enabled":true}'
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/settings/core_services -X PUT -H 'content-type: application/json' --data-raw '{"scanner_enabled":true}'
#create service
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy/draft/services -X POST -H 'content-type: application/json' --data-raw '{"name":"S-taskhostw.exe","description":"","windows_egress_services":[{"process_name":"C:\\Windows\\System32\\taskhostw.exe"}]}'
services_response_href=$(curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy/draft/services | jq -r '.[] | select(.name=="S-taskhostw.exe") | .href')
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy -X POST -H 'content-type: application/json' --data-raw '{"update_description":"","change_subset":{"services":[{"href":"'$services_response_href'"}]}}'
#enable rule hit count on VEN on all scopes
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy/draft/firewall_settings -X PUT -H 'Content-Type: application/json' --data-raw '{"rule_hit_count_enabled_scopes":[[]]}'
#provison
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/sec_policy -X POST -H 'content-type: application/json' --data-raw '{"update_description":"","change_subset":{"firewall_settings":[{"href":"/orgs/1/sec_policy/draft/firewall_settings"}]}}'
#enable rule hit count report
curl -u $auth_username:$session_token https://$(hostname):$port/api/v2/orgs/1/report_templates/rule_hit_count_report -X PUT -H 'Content-Type: application/json' --data-raw '{"enabled": true}'
