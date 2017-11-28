#!/bin/bash

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
    PKGS=$(repoquery --config rock-yum.conf --group --grouppkgs=all --list ${item} 2>/dev/null)
    DEPLIST+="${PKGS}"
  done

  # Add explicit packages
  DEPLIST+="$(cat ks/*.list | grep --color=never -vE '^[%#-]|^$')"
  # Dedupe
  DEPLIST=$(echo ${DEPLIST} | sed 's/ /\n/g' | sort -u | sed -e :a -e '$!N; s/\n/ /; ta')
  echo "Downloading the following packages and their dependencies:"
  echo "${DEPLIST}"
  
  repotrack --config rock-yum.conf --arch=x86_64,noarch --download_path rocknsm_cache/Packages/ ${DEPLIST}

  echo "Signing packages. This can take a while."
  # This will take a while

  setsid -w rpm \
    --define '_gpg_name ROCKNSM 2 Key (ROCKNSM 2 Official Signing Key) <security@rocknsm.io>'  \
    --define '_signature gpg' \
    --define '__gpg_check_password_cmd /bin/true' \
    --define '__gpg_sign_cmd %{__gpg} gpg --batch --no-verbose --no-armor --use-agent --no-secmem-warning -u "%{_gpg_name}" -sbo %{__signature_filename} %{__plaintext_filename}' \
    --addsign ${ROCK_CACHE_DIR}/Packages/*.rpm

  # Clear old repo data & generate fresh
  rm -rf ${ROCK_CACHE_DIR}/repodata
  createrepo_c ${ROCK_CACHE_DIR}
  gpg2 --detach-sign --yes --armor -u security@rocknsm.io ${ROCK_CACHE_DIR}/repodata/repomd.xml

  mkdir -p "${ROCK_CACHE_DIR}/support"
  pushd "${ROCK_CACHE_DIR}/support" >/dev/null

  echo "Downloading ET Snort rules..."
  # ET Rules - Snort
  curl -Ls -o emerging.rules-snort.tar.gz \
    'https://rules.emergingthreats.net/open/snort-2.9.0/emerging.rules.tar.gz'
  gpg2 --detach-sign --yes --armor -u security@rocknsm.io emerging.rules-snort.tar.gz

  echo "Downloading ET Suricata rules..."
  # ET Rules - Suricata
  curl -Ls -o emerging.rules-suricata.tar.gz \
    'https://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz'
  gpg2 --detach-sign --yes --armor -u security@rocknsm.io emerging.rules-suricata.tar.gz

  echo "Downloading pulledpork..."
  # PulledPork:
  curl -Ls -o "pulledpork-$(echo ${PULLEDPORK_RELEASE} | tr '/' '-').tar.gz" \
    "https://github.com/shirkdog/pulledpork/archive/${PULLEDPORK_RELEASE}.tar.gz"
  gpg2 --detach-sign --yes --armor -u security@rocknsm.io "pulledpork-$(echo ${PULLEDPORK_RELEASE} | tr '/' '-').tar.gz"

  echo "Downloading ROCK Scripts..."
  # ROCK-Scripts:
  curl -Ls -o "rock-scripts_$(echo ${ROCKSCRIPTS_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock-scripts/archive/${ROCKSCRIPTS_BRANCH}.tar.gz"
  gpg2 --detach-sign --yes --armor -u security@rocknsm.io "rock-scripts_$(echo ${ROCKSCRIPTS_BRANCH} | tr '/' '-').tar.gz"

  echo "Downloading ROCK Dashboards..."
  # ROCK-Dashboards:
  curl -Ls -o "rock-dashboards_$(echo ${ROCKDASHBOARDS_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock-dashboards/archive/${ROCKDASHBOARDS_BRANCH}.tar.gz"
  gpg2 --detach-sign --yes --armor -u security@rocknsm.io "rock-dashboards_$(echo ${ROCKDASHBOARDS_BRANCH} | tr '/' '-').tar.gz"

#  echo "Downloading ROCK Snapshot..."
#  curl -Ls -o "rock_$(echo ${ROCK_BRANCH} | tr '/' '-').tar.gz" \
#    "https://github.com/rocknsm/rock/archive/${ROCK_BRANCH}.tar.gz"

  # Because I'm pedantic
  popd >/dev/null
}

# Only execute if we are called directly
if [[ "${BASH_SOURCE}" == "${0}" ]]; then
  offline-snapshot $@
fi
