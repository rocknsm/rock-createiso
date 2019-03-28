#!/bin/bash -
LOCAL_MIRROR_USER=$1
LOCAL_MIRROR_PASS=$2
LOCAL_MIRROR_HOST=$3
LOCAL_MIRROR_REPO=$4
LOCAL_MIRROR_PRIVATE=$5
LOCAL_MIRROR_PUBLIC=$6

yum install rsync openssh-clients -y
echo "exporting hidded keys for password less sync"
set +x
mkdir -p /root/.ssh
echo "$LOCAL_MIRROR_PRIVATE" > "/root/.ssh/id_ed25519"
set -x
echo "$LOCAL_MIRROR_PUBLIC" > "/root/.ssh/id_ed25519.pub"
# change the permissions on the keys
chmod 0600 /root/.ssh/*
# Upload to local mirror
rsync -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519" -rv rocknsm-iso/ $LOCAL_MIRROR_USER@$LOCAL_MIRROR_HOST:/var/www/mirror/public/isos/$LOCAL_MIRROR_REPO/
# Sync to public mirror
ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no admin@mirror.cyberlab.lan 'rsync -rlvtP -e "ssh -i ~/.ssh/mirror_sync" /var/www/mirror/ mirror_sync@mirror.rocknsm.io:/var/www/mirror/ --delete'
