#!/bin/bash -
set -x
# Create certificate for pulp-admin
cat <<EOF | tee ~/pulp.cert
"$5"
EOF

# Create pulp admin configuration file
cat <<EOF | tee ~/.pulp/admin.conf
[server]
host = "$3"
verify_ssl = true
ca_path = $HOME/pulp.cert
EOF

# Get auth token
echo "passing hidden values to pulp-admin login"
set +x
pulp-admin login -u $1 -p $2
set -x
# Upload iso file
pulp-admin iso repo uploads upload --dir rocknsm-iso --repo-id $4
