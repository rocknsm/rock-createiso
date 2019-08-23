#!/bin/bash -u
# Copyright 2017, 2018 RockNSM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -x
GPG_KEY_PATH="$(dirname "$(realpath "$0")")/rocknsm-2-sign.asc"
GPG_KEY_NAME="$1"
set +x
GPG_KEY_PASS="$2"
GPG_KEY="$3"
ENABLE_TESTING=$4
OFFICIAL_RELEASE=$5
PULP_HOST=$6

if [[ $OFFICIAL_RELEASE -eq 1 ]]; then
  # Curl the tags and find the latest tag available on github and cut out all the other cruft
  GIT_TAG=$(curl -s https://api.github.com/repos/rocknsm/rock/git/refs/tags \
  | grep \"refs/tags | awk -F'/' '{print $3}' | grep rock | sort | tail -n1 | \
  awk -F'"' '{print $1}' | awk -F"-" '{print $2}')
  ISO_DATE=$(date '+%y%m')
  OUT_ISO="rocknsm-${GIT_TAG}-${ISO_DATE}.iso"
else
  ISO_DATE=$(date '+%Y%m%d-%T')
  OUT_ISO="rocknsm-${ISO_DATE}.iso"
fi
# Create directory to pass to concourse upload task
mkdir -p rocknsm-iso

# create the gpg key on disk to use for signing
echo "$GPG_KEY" > "$GPG_KEY_PATH"
# change working directory
set -x
cd "$(dirname "$(realpath "$0")")"

# Install dependencies
. ../bootstrap.sh

# Create ISO
echo "passing the following variables to master-iso.sh"
echo "-s ../../centos-minimal-iso/centos-minimal.iso"
echo "-o ../../rocknsm-iso/${OUT_ISO}"
echo "-g $GPG_KEY_NAME"
echo "-p HIDDEN PASSWORD"
echo "-i $GPG_KEY_PATH"
echo "-t $ENABLE_TESTING"
echo "-b http://${PULP_HOST}/pulp/repos/centos/7.5/os/"
echo "-e http://${PULP_HOST}/pulp/repos/centos/7.5/extras/"
echo "-E http://${PULP_HOST}/pulp/repos/epel/7/x86_64/"
echo "-u http://${PULP_HOST}/pulp/repos/centos/7.5/updates/"
echo "-l http://${PULP_HOST}/pulp/repos/elastic/6/"

set +x
../master-iso.sh \
-s ../../centos-minimal-iso/centos-minimal.iso \
-o "../../rocknsm-iso/${OUT_ISO}" \
-g "$GPG_KEY_NAME" \
-p "$GPG_KEY_PASS" \
-i "$GPG_KEY_PATH" \
-t "$ENABLE_TESTING" \
-b "http://${PULP_HOST}/pulp/repos/centos/7/os/" \
-e "http://${PULP_HOST}/pulp/repos/centos/7/extras/" \
-E "http://${PULP_HOST}/pulp/repos/epel/7/x86_64/" \
-u "http://${PULP_HOST}/pulp/repos/centos/7/updates/" \
-l "http://${PULP_HOST}/pulp/repos/elastic/7/" \
-a 'https://packagecloud.io/rocknsm/2_4/el/7/$basearch' \
-a 'http://mirror1.internal.perched.io/internal/rock-staging/'
