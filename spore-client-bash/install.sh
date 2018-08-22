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
cp -r ./spore.sh /usr/local/bin/spore
cp -r ./service/spore-service.config /usr/local/etc/spore/spore-service.config
cp -r ./service/spore-service.sh /usr/local/share/spore/spore-service.sh

# Create user
mkdir -p /var/cache/$USER
if ! getent passwd $USER >/dev/null
then
    adduser --system --home /var/cache/$USER $ADDUSERGROUP daemon $USER \
    --shell /bin/false
fi
chown -R $USER /var/cache/$USER

# Create service
mkdir -p $SYSTEMDIR
if [ -e "$SYSTEMDIR/${SPORESRV}.service" ]
then
    systemctl stop $SPORESRV
    systemctl disable $SPORESRV
fi
cp ./service/${SPORESRV}.service $SYSTEMDIR/.

systemctl deamon-reload
systemctl enable $SPORESRV
systemctl start $SPORESRV