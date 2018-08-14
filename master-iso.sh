#!/bin/bash -x
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

NAME="ROCK"
BUILD="$(date +%Y%m%d-%H%M)"
VERSION="2.1"
RELEASE="0beta${BUILD}"
ARCH="x86_64"
KICKSTART="ks.cfg"
KICKSTART_MAN="ks_manual.cfg"
SCRIPT_DIR=$(dirname $(readlink -f $0))
BUILD_LOG="build-${BUILD}.log"
DEBUG=${0:-}
SKIP_GPG='true'

if [ "x${DEBUG}" == "x1" ]; then
    echo "Task output logged to ${BUILD_LOG}"
fi

SRCISO=$(realpath $1)
OUT_ISO="$(dirname ${SRCISO})/rocknsm-${VERSION}-${RELEASE}.iso"
[ $# -eq 2 ] && [ ! -z "$2" ] && OUT_ISO=$(realpath $2)

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

usage() {
  echo "Usage: $0 CentOS-7-x86_64-Everything-1708.iso [output.iso]"
  exit 2
}

if [ $# -lt 1 ] || [ -z "$1" ]; then usage; fi

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
  local COMPS=$(isoinfo -i ${SRCISO} -R -f 2>/dev/null | grep 'comps.xml$' | head -1)
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

download_content() {
  echo "[2/4] Downloading offline snapshot."
  # get current script dir
  CWD="$(dirname "$(realpath "$0")")"
  # Download offline-snapshot
  ansible-playbook --connection=local ${CWD}/ansible/offline-snapshot.yml skip_gpg=${SKIP_GPG}

}

add_content() {
  echo "[3/4] Adding content"

  # Add new isolinux & grub config
  read -r -d '' template_json <<EOF || true
{
  "name": "${NAME}",
  "version": "${VERSION}",
  "arch": "${ARCH}",
  "kickstart": "${KICKSTART}",
  "kickstart_man": "${KICKSTART_MAN}",
  "build": "${BUILD}"
}
EOF

  echo ${template_json} | \
    py 'jinja2.Template(open("isolinux.cfg.j2").read()).render(json.loads(sys.stdin.read()))' | \
    cat - > ${TMP_NEW}/isolinux/isolinux.cfg

  echo ${template_json} | \
    py 'jinja2.Template(open("grub.cfg.j2").read()).render(json.loads(sys.stdin.read()))' | \
    cat - > ${TMP_NEW}/EFI/BOOT/grub.cfg

  # Update efiboot img
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

  local _build_dir="${TMP_NEW}"
  local _iso_fname="${OUT_ISO}"
  local _volid="${NAME} ${VERSION} ${ARCH}"

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
    -eltorito-boot images/efiboot.img \
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

  extract_iso
  download_content
  add_content
  create_iso

}

main
