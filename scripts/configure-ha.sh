#!/bin/bash

set -euo pipefail

tempScript=$(mktemp)

cat <<'EOF' > "$tempScript"
touch /etc/sysctl.d/999-tanzu.conf
chmod +x /etc/sysctl.d/999-tanzu.conf

IFS=$'\n'
for i in $(sysctl -a | grep rp_filter | grep 1);
do
    SYSCTL_SETTING=$(echo ${i} | awk '{print $1}')
    # Update live system
    sysctl -w ${SYSCTL_SETTING}=0
    # Persist settings upon reboot
    echo "${SYSCTL_SETTING}=0" >> /etc/sysctl.d/999-tanzu.conf
done
EOF

# TODO: Fix?
# expect - <<EOF
# spawn ssh root@haproxy "sed -i 's^#PasswordAuthentication yes^PasswordAuthentication yes^g' /etc/ssh/sshd_config"

# expect "Password:"
# send "Rootpass1!\r"
# send "exit\r"

# spawn ssh-copy-id -i /home/vagrant/.ssh/id_ed25519.pub root@haproxy

# expect "Password:"
# send "Rootpass1!\r"
# EOF

scp "$tempScript" haproxy:/tmp/configure-ha.sh 2>/dev/null
scp /tmp/scripts/ping_host haproxy:/usr/bin/

ssh haproxy "bash /tmp/configure-ha.sh" 2>/dev/null
ssh haproxy "rm -f /tmp/configure-ha.sh" 2>/dev/null

rm "$tempScript"
