# Setup installer
install
cdrom
firstboot --enable
eula --agreed
reboot --eject

# Configure Storage
clearpart --all --initlabel
autopart --type=lvm --fstype=xfs
bootloader --location=mbr

# Configure OS
timezone UTC
lang en_US.UTF-8
keyboard us
network --bootproto=dhcp --noipv6 --activate

services --enabled=ssh

# Users
rootpw --lock
#user --name=rockadmin --gecos='ROCK admin account' --groups=wheel

# Security
firewall --enabled --service=ssh
selinux --enforcing
auth --enableshadow --passalgo=sha512 --kickstart

%packages
%include packages.list
%end

# This seems to get removed w/ ksflatten
%addon com_redhat_kdump --disable
%end

%post --nochroot --log=/mnt/sysimage/root/ks-post.log
#!/bin/bash

# Save packages to local repo
mkdir -p /mnt/sysimage/srv/rocknsm
rsync -rP --exclude 'TRANS.TBL' /mnt/install/repo/{Packages,repodata,support} /mnt/sysimage/srv/rocknsm/

# Copy over GPG key
cp -a /mnt/install/repo/RPM-GPG-KEY-RockNSM-2 /mnt/sysimage/etc/pki/rpm-gpg/RPM-GPG-KEY-RockNSM-2

# Copy over build tag & version
mkdir -p /mnt/sysimage/etc/rocknsm/
install -p /.buildstamp  /mnt/sysimage/etc/rocknsm/rocknsm-buildstamp
cat /.buildstamp | awk -F'=' '/Version/ { print $2 }' > /mnt/sysimage/etc/rocknsm/rock-version

%end

%post --log=/root/ks-post-chroot.log
#!/bin/bash

# Allow sudo w/ tools like ansible, etc
sed -i "s/^[^#].*requiretty/#Defaults requiretty/" /etc/sudoers

# Create local repository for ROCK NSM installation
cat << 'EOF' > /etc/yum.repos.d/rocknsm-local.repo
[rocknsm-local]
name=ROCKNSM Local Repository
baseurl=file:///srv/rocknsm
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-RockNSM-2
enabled=1
# Prefer these packages versus online
cost=500
EOF

/usr/sbin/generate_defaults.sh

# Install /etc/issue updater
install -p /usr/share/rock/roles/common/files/etc-issue.in /etc/issue.in
install -p -m 0755 /usr/share/rock/roles/common/files/nm-issue-update /etc/NetworkManager/dispatcher.d/50-rocknsm-issue-update

systemctl enable initial-setup.service

# check for VMware or qemu; Install and enable relevant tools
case $(sudo virt-what) in
  vmware) yum -y install open-vm-tools; systemctl enable vmtoolsd ;;
  qemu)   yum -y install qemu-guest-agent; systemctl enable qemu-guest-agent ;;
esac

%end
