#!/bin/sh
set -euxo pipefail

# delete the system uuid.
# see https://williamlam.com/2013/12/how-to-properly-clone-nested-esxi-vm.html
sed -i -E '/^\/system\/uuid = /d' /etc/vmware/esx.conf

# get rid of harcoded mac address settings.
esxcli system settings advanced set -o /Net/FollowHardwareMac -i 1

# make changes permanent.
/sbin/auto-backup.sh
