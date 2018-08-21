#!/bin/bash

# $USER_PWD gets the path of the folder from which the self-extracting script
# is executed. 

# PKG="spore"
USER="spore"
SYSTEMDIR=/usr/local/lib/systemd/system
SPORESRV="spore-service"

# SRCDIR=$(dirname $0)

# Differences between Ubuntu and Red Hat
OSVERSION=$(cat /proc/version)
ADDUSERGROUP=--ingroup
if [[ "$OSVERSION" =~ "Red Hat" ]];
then
    ADDUSERGROUP=--groups
fi

# Copy files
cp -r $USER_PWD/spore.sh /usr/local/bin/spore
cp -r $USER_PWD/spore.conf /usr/local/etc/spore/spore.conf

mkdir -p /var/cache/$USER
if ! getent passwd $USER >/dev/null
then
    adduser --system --home /var/cache/$USER $ADDUSERGROUP daemon $USER \
    --shell /bin/false
fi
chown -R $USER /var/cache/$USER

mkdir -p $SYSTEMDIR
if [ -e "$SYSTEMDIR/${SPORESRV}.service" ]
then
    systemctl stop $SPORESRV
    systemctl disable $SPORESRV
fi
cp $USER_PWD/systemd/${SPORESRV}.service $SYSTEMDIR/.

systemctl deamon-reload
systemctl enable $SPORESRV
systemctl start $SPORESRV
