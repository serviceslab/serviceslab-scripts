# get-pce-activation-code.sh

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed. Installing it..."
    sudo dnf install -y jq || {
        echo "ERROR: Failed to install jq"
        return 1
    }
fi

basic_auth_token=$(printf '%s' "${pce_admin_username_email_address}:${pce_admin_password}" | base64 --wrap=0)

echo "Authenticating to PCE..."

auth_token=$(
    curl -ksS --fail -X POST \
        -H "Authorization: Basic ${basic_auth_token}" \
        "https://${fqdn}:${port}/api/v2/login_users/authenticate?pce_fqdn=${fqdn}" |
        jq -er '.auth_token'
) || {
    echo "ERROR: Failed to authenticate to the PCE"
    return 1
}

echo "Creating PCE session..."

login_response=$(
    curl -ksS --fail \
        -H "Authorization: Token token=${auth_token}" "https://${fqdn}:${port}/api/v2/users/login"
) || {
    echo "ERROR: Failed to create the PCE login session"
    return 1
}

auth_username=$(
    printf '%s' "$login_response" | jq -er '.auth_username' ) || {
    echo "ERROR: auth_username was missing from the login response"
    return 1
}

session_token=$( printf '%s' "$login_response" | jq -er '.session_token' ) || {
    echo "ERROR: session_token was missing from the login response"
    return 1
}

echo "Requesting pairing profile activation code..."

activation_code=$(
    curl -ksS --fail -X POST \
        -u "${auth_username}:${session_token}" \
        -H 'Content-Type: application/json' \
        --data-raw '{}' \
        "https://${fqdn}:${port}/api/v2/orgs/1/pairing_profiles/1/pairing_key" |
        jq -er '.activation_code'
) || {
    echo "ERROR: Failed to obtain the activation code"
    return 1
}

export activation_code

echo "Activation code successfully retrieved"