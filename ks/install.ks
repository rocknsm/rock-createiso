# Setup installer
install
cdrom
firstboot --enable
eula --agreed
reboot --eject

# Configure Storage
ignoredisk --only-use=sda
clearpart --all --initlabel --drives=sda
autopart --type=lvm
bootloader --location=mbr --boot-drive=sda

# Configure OS
timezone UTC
lang en_US.UTF-8
keyboard us
network --bootproto=dhcp --noipv6 --activate
unsupported_hardware

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
cp -a /mnt/install/repo/RPM-GPG-KEY-RockNSM-2 /etc/pki/rpm-gpg/RPM-GPG-KEY-RockNSM-2

%end

%post --log=/root/ks-post-chroot.log
#!/bin/bash

ROCK_DIR=/opt/rocknsm/rock

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

# Default to offline build and generate values
mkdir -p /etc/rocknsm
cat << 'EOF' > /etc/rocknsm/config.yml
---
rock_online_install: False
EOF

${ROCK_DIR}/bin/generate_defaults.sh

# Set version id
echo "2.1.0" > /etc/rocknsm/rock-version

# Install /etc/issue updater
cp ${ROCK_DIR}/playbooks/files/etc-issue.in /etc/issue.in
cp ${ROCK_DIR}/playbooks/files/nm-issue-update /etc/NetworkManager/dispatcher.d/50-rocknsm-issue-update
chmod 755 /etc/NetworkManager/dispatcher.d/50-rocknsm-issue-update

systemctl enable initial-setup-graphical.service

%end
