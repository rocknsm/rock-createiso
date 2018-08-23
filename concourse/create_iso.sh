#!/bin/bash -xu
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

# change working directory
cd "$(dirname "$(realpath "$0")")"
GPG_KEY_PATH="$(dirname "$(realpath "$0")")/rocknsm-2-sign.asc"
GPG_KEY_NAME="$1"
GPG_KEY_PASS="$2"
GPG_KEY="$3"

if [[ GPG_KEY_NAME ]]; then
  echo "GPG_KEY_NAME: $GPG_KEY_NAME"
  echo "GPG_KEY_PASS: $GPG_KEY_PASS"
  echo "GPG_KEY: $GPG_KEY"
  exit 0
fi
# Install dependencies
. ../bootstrap.sh

if [[ $GPG_KEY ]]; then
    echo "$GPG_KEY" > "$GPG_KEY_PATH"
fi

# Create ISO
../master-iso.sh \
-s ../../centos-minimal-iso/centos-minimal.iso \
-o "rocknsm-$(date '+%Y%m%d').iso" \
-g $GPG_KEY_NAME \
-p $GPG_KEY_PASS \
-i $GPG_KEY_PATH \
