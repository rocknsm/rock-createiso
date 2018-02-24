#!/bin/bash
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

ROCK_CACHE_DIR=rocknsm_cache
ROCK_REPO=2_1
ROCKSCRIPTS_BRANCH=master
ROCKDASHBOARDS_BRANCH=master
#ROCK_BRANCH=master
PULLEDPORK_RELEASE=0.7.2
TMP_RPM_ROOT=$(mktemp -d)

function cleanup-snapshot () {
  rm -rf ${TMP_RPM_ROOT}
}

trap cleanup-snapshot EXIT

function offline-snapshot () {

  # Create the dest dir for packages
  mkdir -p "${ROCK_CACHE_DIR}/Packages"

  DEPLIST=""
  PKGGROUPS=$(cat ks/*.list | grep --color=never '@' | tr -d '@')

  # List group packages
  for item in ${PKGGROUPS}; do
    echo "Adding package group: ${item}"
    PKGS=$(repoquery --config rock-yum.conf --group --grouppkgs=all --list ${item} 2>/dev/null)
    DEPLIST+="${PKGS}"
  done

  # Add explicit packages
  DEPLIST+="$(cat ks/*.list | grep --color=never -vE '^[@%#-]|^$')"
  # Dedupe
  DEPLIST=$(echo ${DEPLIST} | sed 's/ /\n/g' | sort -u | sed -e :a -e '$!N; s/\n/ /; ta')
  echo "Downloading the following packages and their dependencies:"
  echo "${DEPLIST}"

  # Download _ALL_ dependencies
  repotrack --config rock-yum.conf --download_path ${ROCK_CACHE_DIR}/Packages/ ${DEPLIST}
  if [ "$?" -ne "0" ]; then
      echo "Downloading packages failed."
      exit 1
  fi

  # Remove the i686 stuff
  echo "Removing i686 packages"
  ls ${ROCK_CACHE_DIR}/Packages/*i686.rpm
  rm ${ROCK_CACHE_DIR}/Packages/*i686.rpm

  SKIP_GPG=0
  if [ -z "${CONTINUOUS_INTEGRATION}" ] && [ "${CONTINUOUS_INTEGRATION}" != "true" ]; then
    SKIP_GPG=1
  fi

  if [ "${SKIP_GPG}" -eq "0" ]; then
    echo "Signing packages. This can take a while."
    # This will take a while

    setsid -w rpm \
      --define '_gpg_name ROCKNSM 2 Key (ROCKNSM 2 Official Signing Key) <security@rocknsm.io>'  \
      --define '_signature gpg' \
      --define '__gpg_check_password_cmd /bin/true' \
      --define '__gpg_sign_cmd %{__gpg} gpg --batch --no-verbose --no-armor --use-agent --no-secmem-warning -u "%{_gpg_name}" -sbo %{__signature_filename} %{__plaintext_filename}' \
      --addsign ${ROCK_CACHE_DIR}/Packages/*.rpm
  fi

  # Clear old repo data & generate fresh
  rm -rf ${ROCK_CACHE_DIR}/repodata
  createrepo_c ${ROCK_CACHE_DIR}
  if [ "${SKIP_GPG}" -eq "0" ]; then
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io ${ROCK_CACHE_DIR}/repodata/repomd.xml
  fi

  mkdir -p "${ROCK_CACHE_DIR}/support"
  pushd "${ROCK_CACHE_DIR}/support" >/dev/null

  echo "Downloading ET Snort rules..."
  # ET Rules - Snort
  curl -Ls -o emerging.rules-snort.tar.gz \
    'https://rules.emergingthreats.net/open/snort-2.9.0/emerging.rules.tar.gz'
  if [ "${SKIP_GPG}" -eq "0" ]; then
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io emerging.rules-snort.tar.gz
  fi

  echo "Downloading ET Suricata rules..."
  # ET Rules - Suricata
  curl -Ls -o emerging.rules-suricata.tar.gz \
    'https://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz'

  if [ "${SKIP_GPG}" -eq "0" ]; then
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io emerging.rules-suricata.tar.gz
  fi

  echo "Downloading pulledpork..."
  # PulledPork:
  curl -Ls -o "pulledpork-$(echo ${PULLEDPORK_RELEASE} | tr '/' '-').tar.gz" \
    "https://github.com/shirkdog/pulledpork/archive/${PULLEDPORK_RELEASE}.tar.gz"
  if [ "${SKIP_GPG}" -eq "0" ]; then
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io "pulledpork-$(echo ${PULLEDPORK_RELEASE} | tr '/' '-').tar.gz"
  fi
  echo "Downloading ROCK Scripts..."
  # ROCK-Scripts:
  curl -Ls -o "rock-scripts_$(echo ${ROCKSCRIPTS_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock-scripts/archive/${ROCKSCRIPTS_BRANCH}.tar.gz"

  if [ "${SKIP_GPG}" -eq "0" ]; then
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io "rock-scripts_$(echo ${ROCKSCRIPTS_BRANCH} | tr '/' '-').tar.gz"
  fi

  echo "Downloading ROCK Dashboards..."
  # ROCK-Dashboards:
  curl -Ls -o "rock-dashboards_$(echo ${ROCKDASHBOARDS_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock-dashboards/archive/${ROCKDASHBOARDS_BRANCH}.tar.gz"
  if [ "${SKIP_GPG}" -eq "0" ]; then
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io "rock-dashboards_$(echo ${ROCKDASHBOARDS_BRANCH} | tr '/' '-').tar.gz"
  fi

  # Because I'm pedantic
  popd >/dev/null
}

# Only execute if we are called directly
if [[ "${BASH_SOURCE}" == "${0}" ]]; then
  offline-snapshot $@
fi
