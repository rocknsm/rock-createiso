#!/bin/bash -eux

ROCK_REPO=2
ROCKSCRIPTS_BRANCH=devel
ROCKDASHBOARDS_BRANCH=master
ROCK_BRANCH=devel
PULLEDPORK_RELEASE=0.7.2
TMP_RPM_ROOT=$(mktemp -d)
SCRIPT_DIR=$(dirname $(readlink -f $0))
ROCK_CACHE_DIR=${SCRIPT_DIR}/rock_cache

function cleanup-snapshot () {
  rm -rf ${TMP_RPM_ROOT}
}

trap cleanup-snapshot EXIT

function offline-snapshot () {

  ROCK_CACHE_DIR=${1:-ROCK_CACHE_DIR}

  # Requires to run as root
  #if [ $(id -u) != 0 ]; then echo "Run this script as root (try sudo)"; exit 1; fi
  mkdir -p ${TMP_RPM_ROOT}
  mkdir -p "${ROCK_CACHE_DIR}/Packages"

  # Download rock packages for later install
  cat ks/rock_packages.list \
      ks/installer_packages.list \
       ks/local.list \
       ks/packages.list | \
  grep -vE '^[%#-]|^$'  | \
    awk '{print$1}' | \
    xargs yum -c src/yum/rock-2-x86_64.conf \
      install --downloadonly \
      --installroot=${TMP_RPM_ROOT} \
      --downloaddir=${ROCK_CACHE_DIR}/Packages/

  # Clear old repo data & generate fresh
  rm -rf ${ROCK_CACHE_DIR}/repodata
  createrepo ${ROCK_CACHE_DIR}

  mkdir -p "${ROCK_CACHE_DIR}/support"
  pushd "${ROCK_CACHE_DIR}/support" >/dev/null

  echo "Downloading ET Snort rules..."
  # ET Rules - Snort
  curl -Ls -o emerging.rules-snort.tar.gz \
    'https://rules.emergingthreats.net/open/snort-2.9.0/emerging.rules.tar.gz'

  echo "Downloading ET Suricata rules..."
  # ET Rules - Suricata
  curl -Ls -o emerging.rules-suricata.tar.gz \
    'https://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz'

  echo "Downloading pulledpork..."
  # PulledPork:
  curl -Ls -o "pulledpork-$(echo ${PULLEDPORK_RELEASE} | tr '/' '-').tar.gz" \
    "https://github.com/shirkdog/pulledpork/archive/${PULLEDPORK_RELEASE}.tar.gz"

  echo "Downloading ROCK Scripts..."
  # ROCK-Scripts:
  curl -Ls -o "rock-scripts_$(echo ${ROCKSCRIPTS_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock-scripts/archive/${ROCKSCRIPTS_BRANCH}.tar.gz"

  echo "Downloading ROCK Dashboards..."
  # ROCK-Dashboards:
  curl -Ls -o "rock-dashboards_$(echo ${ROCKDASHBOARDS_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock-dashboards/archive/${ROCKDASHBOARDS_BRANCH}.tar.gz"

  echo "Downloading ROCK Snapshot..."
  curl -Ls -o "rock_$(echo ${ROCK_BRANCH} | tr '/' '-').tar.gz" \
    "https://github.com/rocknsm/rock/archive/${ROCK_BRANCH}.tar.gz"

  # Because I'm pedantic
  popd >/dev/null
}

# Only execute if we are called directly
if [[ "${BASH_SOURCE}" == "${0}" ]]; then
  offline-snapshot $@
fi
