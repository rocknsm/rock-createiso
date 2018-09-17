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
echo "-o ../../rocknsm-iso/rocknsm-$(date '+%Y%m%d').iso"
echo "-g $GPG_KEY_NAME"
echo "-p HIDDEN PASSWORD"
echo "-i $GPG_KEY_PATH"

set +x
../master-iso.sh \
-s ../../centos-minimal-iso/centos-minimal.iso \
-o "rocknsm-$(date '+%Y%m%d').iso" \
-g "$GPG_KEY_NAME" \
-p "$GPG_KEY_PASS" \
-i "$GPG_KEY_PATH"
