#!/bin/bash -x

# RedHat Prep
if grep "Red Hat Enterprise Linux Server" /etc/system-release; then
  ## Get current repo configurations for optional and extras
  eval $(cat enabled_repos.txt | awk '/rhel-7-server-optional/{o=1}; o && /Enabled:/ { opts_enabled=$2; o=0}; /rhel-7-server-extras/{e=1}; e && /Enabled:/ {extras_enabled=$2;e=0}; END { print "extras=" extras_enabled; print "optional=" opts_enabled }')
  
  if [[ $optional -ne 1 ]]; then
   subscription-manager repos --enable=rhel-7-server-optional-rpms 
  fi
  
  if [[ $extras -ne 1 ]]; then
   subscription-manager repos --enable=rhel-7-server-extras-rpms 
  fi

  yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
else
  yum -y install epel-release
fi

yum -y install python-pip python-jinja2 python-simplejson genisoimage pykickstart createrepo rsync isomd5sum syslinux pigz mock fuseiso libguestfs-tools-c initial-setup-gui firstboot

pip install pythonpy

