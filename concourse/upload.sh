#!/bin/bash -
PULP_USER=$1
PULP_PASS=$2
PULP_HOST=$3
PULP_REPO=$4
PULP_CERT=$5
UPLOAD_TRIES=0
UPLOAD_CODE=''
UPLOAD_MAX_TRIES=3

function upload_iso {
  pulp-admin iso repo uploads upload --dir rocknsm-iso --repo-id $PULP_REPO
  if [[ $? -ne 0 ]]; then
    if [[ $UPLOAD_TRIES -ge $UPLOAD_MAX_TRIES ]]; then
      exit 1
    fi
  else
    UPLOAD_TRIES=$UPLOAD_MAX_TRIES
  fi
}

set -x
# Create certificate for pulp-admin
cat <<EOF | tee -a /etc/tls/certs/ca-bundle.crt
$PULP_CERT
EOF

# Create pulp admin configuration file
cat <<EOF | tee ~/.pulp/admin.conf
[server]
host = $PULP_HOST
verify_ssl = true
EOF

# Get auth token
echo "passing hidden values to pulp-admin login"
set +x
pulp-admin login -u $PULP_USER -p $PULP_PASS
set -x
# Upload iso file
while [[ $UPLOAD_TRIES -lt $UPLOAD_MAX_TRIES ]]; do
  upload_iso
  ((++UPLOAD_TRIES))
done

pulp-admin iso repo publish run --repo-id $PULP_REPO
