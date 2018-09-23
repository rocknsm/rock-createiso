#!/bin/bash -
PULP_USER=$1
PULP_PASS=$2
PULP_HOST=$3
PULP_REPO=$4
PULP_CERT=$5


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
pulp-admin iso repo uploads upload --dir rocknsm-iso --repo-id $PULP_REPO

pulp-admin iso repo publish run --repo-id $PULP_REPO
