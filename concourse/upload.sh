#!/bin/bash

cat <<EOF | tee ~/.pulp/admin.conf
[server]
host = http://mirror.rocknsm.io
verify_ssl = false
EOF

pulp-admin login -u $1 -p $2

pulp-admin iso repo uploads upload --dir rocknsm-iso --repo-id rocknsm-nightly --bg
