#!/bin/bash

set -eou pipefail

ping_host client 10.10.0.2
ping_host client 10.20.0.2

ssh router /bin/bash 2>/dev/null << EOF
    ping_host router 192.168.122.6
    ping_host router 10.10.0.2
    ping_host router 10.20.0.2
EOF

ssh haproxy 'bash -s' 2>/dev/null << EOF
    ping_host haproxy 10.10.0.2
    ping_host haproxy 10.20.0.2
EOF
