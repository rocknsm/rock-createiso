#!/bin/bash -
set -x
cat <<EOF | tee ~/.pulp/admin.conf
[server]
host = "$3"
verify_ssl = false
EOF
echo "passing hidden values to pulp-admin login"
set +x
pulp-admin login -u $1 -p $2
set -x
pulp-admin iso repo uploads upload --dir rocknsm-iso --repo-id rocknsm-nightly --bg
