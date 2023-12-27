#!/bin/sh

sed -i 's,^\(passwordauthentication \).*,\1yes,g' /etc/ssh/sshd_config
