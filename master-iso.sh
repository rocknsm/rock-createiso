#!/bin/bash -eu
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
OUT_ISO=''
SRCISO=''
HELP=''
GPG_KEY_NAME=''
GPG_PASS=''
GPG_KEY_PATH=''
RPM_GPG_KEY=''
NAME="ROCK"
BUILD="$(date +%Y%m%d-%H%M)"
VERSION="2.3"
RELEASE="$(date +%y%m)"
ARCH="x86_64"
KICKSTART="ks.cfg"
KICKSTART_MAN="ks_manual.cfg"
SCRIPT_DIR=$(dirname $(readlink -f $0))
BUILD_LOG="build-${BUILD}.log"
DEBUG=${0:-}
SKIP_GPG='true'
ROCK_CACHE_DIR=${SCRIPT_DIR}'/rocknsm_cache'
ROCK_RELEASE='RockNSM release ${VERSION}.${RELEASE} (Core)'
YUM_ADDITIONAL_URLS=()

while getopts 'o:s:g:p:i:t:b:e:E:u:l:a:h' flag; do
  case "${flag}" in
    o) OUT_ISO=$(realpath "${OPTARG}") ;;
    s) SRCISO=$(realpath "${OPTARG}") ;;
    g) GPG_KEY_NAME="${OPTARG}" ;;
    p) GPG_PASS="${OPTARG}";;
    i) GPG_KEY_PATH="${OPTARG}";;
    t) YUM_TESTING="${OPTARG}";;
    b) YUM_BASE_URL="${OPTARG}";;
    e) YUM_EXTRAS_URL="${OPTARG}";;
    E) YUM_EPEL_URL="${OPTARG}";;
    u) YUM_UPDATES_URL="${OPTARG}";;
    l) YUM_ELASTIC_URL="${OPTARG}";;
    a) YUM_ADDITIONAL_URLS+=("${OPTARG}");;
    h) HELP='true' ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

usage() {
  echo "Usage: `basename $0` -s source.iso [-o output.iso] [-g gpg-key-name] [-p gpg-password] [-i gpg-key-path]"
  echo
  echo "  -o, path to create output ISO"
  echo "  -s, path to source ISO"
  echo "  -g, long name of gpg key to use"
  echo "  -p, GPG Pass phrase"
  echo "  -i, Path to gpg key file to import"
  echo "  -t, Enable testing repo (1) or disable (0). Default: 0"
  echo "  -b, Yum base url"
  echo "  -e, Yum extras url"
  echo "  -E, Yum EPEL url"
  echo "  -u, Yum updates url"
  echo "  -l, Yum elastic url"
  echo "  -a, Additional Yum url. Can be used multiple times"
  exit 2
}

if [[ $HELP ]]; then usage; fi

if ! [[ $SRCISO ]]; then usage; fi

if ! [[ $OUT_ISO ]]; then
  OUT_ISO="$(dirname ${SRCISO})/rocknsm-${VERSION}-${RELEASE}.iso"
fi

# We recieved a key and password, so we would use them
if [[ $GPG_KEY_NAME && $GPG_PASS ]]; then
  SKIP_GPG='false'
else
  SKIP_GPG='true'
fi

if [[ $GPG_KEY_PATH ]]; then
  # validate they also gave us a key and password
  if ! [[ $GPG_KEY_NAME && $GPG_PASS ]]; then
    echo "Error: Need Key name and Password when importing a key"
    usage
  fi
fi

if [ "x${DEBUG}" == "x1" ]; then
    echo "Task output logged to ${BUILD_LOG}"
fi

if [ -z ${YUM_TESTING+x} ]; then
  YUM_TESTING=0
fi

TMP_ISO=$(mktemp -d)
TMP_NEW=$(mktemp -d)
TMP_RPMDB=$(mktemp -d)
TMP_EFIBOOT=$(mktemp -d)

cleanup() {
  [ -d ${TMP_ISO} ] && rm -rf ${TMP_ISO}
  [ -d ${TMP_NEW} ] && rm -rf ${TMP_NEW}
  [ -d ${TMP_RPMDB} ] && rm -rf ${TMP_RPMDB}
  [ -d ${TMP_EFIBOOT} ] && rm -rf ${TMP_EFIBOOT}
}

trap cleanup EXIT

check_depends() {
  which mkisofs    # genisoimage
  which flattenks  # pykiskstart
  which createrepo # createrepo
  which ansible-playbook # offline snapshot
}

die() { echo "ERROR: $@" >&2 ; exit 2 ; }

cond_out() { "$@" 2>&1 | tee -a ${BUILD_LOG} > .tmp.log 2>&1 || { cat .tmp.log >&2 ; die "Failed to run $@" ; } && rm .tmp.log || : ; return $? ; }

extract_iso() {
  echo "[1/4] Extracting ISO"

  # Might want to comment this out if you're sure of your ISO
  #cond_out checkisomd5 --verbose ${SRCISO}

  ## This approach doesn't require root, but it was truncating filenames :-(
  local ISOFILES=$(isoinfo -i ${SRCISO} -R -f 2>/dev/null | sort -r | grep -vE '/Packages|/repodata|TRANS.TBL')
  for F in ${ISOFILES}
  do
    mkdir -p ${TMP_NEW}/$(dirname $F)
    [[ -d ${TMP_NEW}/.$F ]] || { isoinfo -i ${SRCISO} -R -x $F > ${TMP_NEW}/.$F 2>/dev/null ; }
  done

  # Extract comps file
  local COMPS=$(isoinfo -i ${SRCISO} -R -f 2>/dev/null | grep 'comps.*\.xml$' | head -1)
  mkdir -p ${TMP_NEW}/repodata
  isoinfo -i ${SRCISO} -R -x "${COMPS}" 2>/dev/null > ${TMP_NEW}/repodata/comps.xml

  # Mount existing iso and copy to new dir
  #cond_out mount -o loop -t iso9660 "${SRCISO}" ${TMP_ISO}
  #cond_out rsync --recursive --exclude=Packages --exclude=repodata ${TMP_ISO}/ ${TMP_NEW}/
  #cond_out mkdir -p ${TMP_NEW}/repodata
  #cond_out cp $(ls ${TMP_ISO}/repodata/*comps*.xml | head -1 ) ${TMP_NEW}/repodata/comps.xml
  #cond_out umount ${TMP_ISO}

  # Remove TRANS files
  #find ${TMP_NEW} -name TRANS.TBL -delete

}

install_gpg_key() {
  # Import gpg key if they gave us the path
  # Check to see if the key was previously imported
  if [[ ! $(gpg --list-secret-keys --keyid-format LONG | grep "${GPG_KEY_NAME}") ]]; then
    RPM_GPG_KEY="${SCRIPT_DIR}/RPM-GPG-KEY-ROCKNSM"
    gpg --import "${GPG_KEY_PATH}"
    gpg --export -a "${GPG_KEY_NAME}" > "${RPM_GPG_KEY}"
    rpm --import "${RPM_GPG_KEY}"
  fi
}

download_content() {
  # echo "[2/4] Downloading offline snapshot."
  # # Download offline-snapshot
  # echo "passing the following vars to ansible."
  # echo "${SCRIPT_DIR}/ansible/offline-snapshot.yml"
  # echo "${SKIP_GPG}"
  # echo "HIDDEN PASSWORD"
  # echo "${GPG_KEY_NAME}"

  # Create the extra vars file and while we are here make sure its empty
  echo "foo: bar" > /tmp/extra-vars.yml

  # Check what yum urls need to be overriden in assible
  if [[ ! -z ${YUM_BASE_URL+x} ]]; then
    echo "yum_base_url: '${YUM_BASE_URL}'" >> /tmp/extra-vars.yml
  fi
  if [[ ! -z ${YUM_EXTRAS_URL+x} ]]; then
    echo "yum_extras_url: '${YUM_EXTRAS_URL}'" >> /tmp/extra-vars.yml
  fi
  if [[ ! -z ${YUM_EPEL_URL+x} ]]; then
    echo "yum_epel_url: '${YUM_EPEL_URL}'" >> /tmp/extra-vars.yml
  fi
  if [[ ! -z ${YUM_UPDATES_URL+x} ]]; then
    echo "yum_updates_url: '${YUM_UPDATES_URL}'" >> /tmp/extra-vars.yml
  fi
  if [[ ! -z ${YUM_ELASTIC_URL+x} ]]; then
    echo "yum_elastic_url: '${YUM_ELASTIC_URL}'" >> /tmp/extra-vars.yml
  fi
  if [[ ! -z ${YUM_ADDITIONAL_URLS+x} ]]; then
    echo "yum_additional_urls: " >> /tmp/extra-vars.yml
    for item in "${YUM_ADDITIONAL_URLS}"; do
      echo " - ${item}" >> /tmp/extra-vars.yml
    done
  fi

  echo "Running the following ansible command"
  echo "ansible-playbook --connection=local ${SCRIPT_DIR}/ansible/offline-snapshot.yml"
  echo "-vvvv -e skip_gpg='${SKIP_GPG}'"
  echo "-e rock_cache_dir='${ROCK_CACHE_DIR}'"
  echo "-e gpg_passphrase='HIDDEN PASSWORD'"
  echo "-e gpg_key_name='${GPG_KEY_NAME}'"
  echo "-e yum_rocknsm_testing_enabled='${YUM_TESTING}'"
  echo "-e @/tmp/extra-vars.yml"

  set +x
  ansible-playbook --connection=local ${SCRIPT_DIR}/ansible/offline-snapshot.yml  \
  -vvvv -e "skip_gpg='${SKIP_GPG}'" \
  -e "rock_cache_dir='${ROCK_CACHE_DIR}'"  \
  -e "gpg_passphrase='${GPG_PASS}'"  \
  -e "gpg_key_name='${GPG_KEY_NAME}'"  \
  -e "yum_rocknsm_testing_enabled='${YUM_TESTING}'" \
  -e "@/tmp/extra-vars.yml"
  set -x
}

add_content() {
  echo "[3/4] Adding content"
  cd ${SCRIPT_DIR}
  # Add new isolinux & grub config
  read -r -d '' template_json <<EOF || true
{
  "name": "${NAME}",
  "version": "${VERSION}-${RELEASE}",
  "arch": "${ARCH}",
  "kickstart": "${KICKSTART}",
  "kickstart_man": "${KICKSTART_MAN}",
  "build": "${BUILD}"
}
EOF

  echo ${template_json} | \
    py 'jinja2.Template(open("templates/isolinux.cfg.j2").read()).render(json.loads(sys.stdin.read()))' | \
    cat - > ${TMP_NEW}/isolinux/isolinux.cfg

  echo ${template_json} | \
    py 'jinja2.Template(open("templates/grub.cfg.j2").read()).render(json.loads(sys.stdin.read()))' | \
    cat - > ${TMP_NEW}/EFI/BOOT/grub.cfg

  echo ${template_json} | \
    py 'jinja2.Template(open("templates/os-release.j2").read()).render(json.loads(sys.stdin.read()))' | \
    cat - > ${SCRIPT_DIR}/product/etc/os-release

  echo ${template_json} | \
    py 'jinja2.Template(open("templates/buildstamp.j2").read()).render(json.loads(sys.stdin.read()))' | \
    cat - > ${SCRIPT_DIR}/product/.buildstamp

  echo ${ROCK_RELEASE} | \
    tee ${SCRIPT_DIR}/product/etc/centos-release | \
    tee ${SCRIPT_DIR}/product/etc/redhat-release | \
    tee ${SCRIPT_DIR}/product/etc/system-release > /dev/null

  # Update efiboot img
  export MTOOLS_SKIP_CHECK=1
  mcopy -Do -i ${TMP_NEW}/images/efiboot.img \
      ${TMP_NEW}/EFI/BOOT/grub.cfg \
      ::/EFI/BOOT/grub.cfg

  # Copy UEFI splash branding
  cp ${SCRIPT_DIR}/images/uefi_splash_rock.png ${TMP_NEW}/EFI/BOOT/uefi_splash_rock.png

  # Copy boot splash branding
  cp ${SCRIPT_DIR}/images/splash_rock.png ${TMP_NEW}/isolinux/splash.png

  # Setup UEFI branding
  mkdir ${TMP_NEW}/EFI/BOOT/x86_64-efi
  cp /usr/lib/grub/x86_64-efi/gfxterm_background.mod ${TMP_NEW}/EFI/BOOT/x86_64-efi/

  # Generate product image
  cd ${SCRIPT_DIR}/product
  find . | cpio -c -o 2>/dev/null| gzip -9cv > ../product.img 2>/dev/null
  cd ${SCRIPT_DIR}
  mkdir -p ${TMP_NEW}/images
  cp product.img ${TMP_NEW}/images/

  # Sync over offline content
  cp -a ${ROCK_CACHE_DIR}/* ${TMP_NEW}/

  # Create new repo metadata
  createrepo_c -g ${TMP_NEW}/repodata/comps.xml ${TMP_NEW}
  if [[ "${SKIP_GPG}" == "false" ]]; then
    echo "Running gpg2 sign"
    set +x
    if [[ "${GPG_PASS}" ]]; then
      gpg2 --detach-sign --yes --armor --passphrase "${GPG_PASS}" --batch -u security@rocknsm.io ${TMP_NEW}/repodata/repomd.xml
    else
      gpg2 --detach-sign --yes --armor -u security@rocknsm.io ${TMP_NEW}/repodata/repomd.xml
    fi
    set -x
  fi

  rm  ${TMP_NEW}/repodata/comps.xml

  # Generate flattened manual kickstart & add pre-inst hooks
  ksflatten -c ks/install.ks -o "${TMP_NEW}/${KICKSTART}"

  cat <<EOF >> "${TMP_NEW}/${KICKSTART}"

# This seems to get removed w/ ksflatten
%addon com_redhat_kdump --disable
%end
EOF

  # Generate flattened automated kickstart & add pre-inst hooks
  ksflatten -c ks/manual.ks -o "${TMP_NEW}/${KICKSTART_MAN}"

  cat <<EOF >> "${TMP_NEW}/${KICKSTART_MAN}"

# This seems to get removed w/ ksflatten
%addon com_redhat_kdump --disable
%end
EOF

  # Copy over GPG key
  cp -a "${SCRIPT_DIR}/RPM-GPG-KEY-RockNSM-2" "${TMP_NEW}/RPM-GPG-KEY-RockNSM-2"

  # Generate BuildTag
  echo "${BUILD}" > "${TMP_NEW}/RockNSM_BuildTag"

}

create_iso() {

  echo "[4/4] Creating new ISO"
  cd ${SCRIPT_DIR}
  local _build_dir="${TMP_NEW}"
  local _iso_fname="${OUT_ISO}"
  local _volid="${NAME} ${VERSION}-${RELEASE} ${ARCH}"

  echo "Dumping tree listing"
  tree ${_build_dir}

  # This is the genisoimage version of mkisofs
  /usr/bin/mkisofs -J \
    -translation-table \
    -untranslated-filenames \
    -joliet-long \
    -o ${_iso_fname} \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e images/efiboot.img \
    -no-emul-boot \
    -rock \
    -rational-rock \
    -graft-points \
    -appid "${_volid}" \
    -V "${_volid}" \
    ${_build_dir}
  isohybrid --uefi ${_iso_fname}
  implantisomd5 --force ${_iso_fname}
}

main() {
  set -x
  extract_iso
  # only install the gpg key if they passed it in
  if [[ $GPG_KEY_PATH ]]; then install_gpg_key; fi
  download_content
  add_content
  create_iso

}

main
