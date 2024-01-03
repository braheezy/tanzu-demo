#!/bin/bash

DOMAIN=esxi.test
BASE_IP_RANGE=192.168.122
PHOTON_ROUTER_IP=$BASE_IP_RANGE.2
PHOTON_ROUTER_GW=$BASE_IP_RANGE.1
PHOTON_ROUTER_DNS=$BASE_IP_RANGE.1
SETUP_DNS_SERVER=1

tdnf -y update
if [ ${SETUP_DNS_SERVER} -eq 1 ]; then
    tdnf install -y unbound bindutils

    cat > /etc/unbound/unbound.conf << EOF
    server:
        interface: 0.0.0.0
        port: 53
        do-ip4: yes
        do-udp: yes
        access-control: $BASE_IP_RANGE.0/24 allow
        access-control: 10.10.0.0/24 allow
        access-control: 10.20.0.0/24 allow
        verbosity: 1
        chroot: ""
        logfile: /var/log/unbound.log
        log-queries: yes

    local-zone: "$DOMAIN." static

    local-data: "router.$DOMAIN A $BASE_IP_RANGE.2"
    local-data-ptr: "$BASE_IP_RANGE.2 router.$DOMAIN"

    local-data: "vcsa.$DOMAIN A $BASE_IP_RANGE.5"
    local-data-ptr: "$BASE_IP_RANGE.5 vcsa.$DOMAIN"

    local-data: "haproxy.$DOMAIN A $BASE_IP_RANGE.6"
    local-data-ptr: "$BASE_IP_RANGE.6 haproxy.$DOMAIN"

    local-data: "esxi-1.$DOMAIN A $BASE_IP_RANGE.77"
    local-data-ptr: "$BASE_IP_RANGE.77 esxi-1.$DOMAIN"

    forward-zone:
        name: "."
        forward-addr: ${PHOTON_ROUTER_DNS}
EOF

    # So unbound can use port 53
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

    systemctl enable unbound
    systemctl start unbound
fi

sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.d/50-security-hardening.conf
sysctl -w net.ipv4.ip_forward=1

rm -f /etc/systemd/network/99-dhcp-en.network

cat > /etc/systemd/network/10-static-eth0.network << EOF
[Match]
Name=eth0

[Network]
Address=${PHOTON_ROUTER_IP}/24
Gateway=${PHOTON_ROUTER_GW}
DNS=${PHOTON_ROUTER_DNS}
IPv6AcceptRA=no
EOF

cat > /etc/systemd/network/11-static-eth1.network << EOF
[Match]
Name=eth1

[Network]
Address=10.10.0.1/24
EOF

cat > /etc/systemd/network/12-static-eth2.network << EOF
[Match]
Name=eth2

[Network]
Address=10.20.0.1/24
EOF

chmod 655 /etc/systemd/network/*
systemctl restart systemd-networkd

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
if [ ${SETUP_DNS_SERVER} -eq 1 ]; then
    iptables -A INPUT -i eth0 -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -i eth1 -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -i eth2 -p udp --dport 53 -j ACCEPT
fi
iptables-save > /etc/systemd/scripts/ip4save

systemctl restart iptables

# Sanity check
if nslookup google.com $PHOTON_ROUTER_IP &>/dev/null; then
    echo "Lookup to google.com works!"
else
    echo "Lookup to google.com failed :("
    exit 1
fi
if nslookup vcsa.$DOMAIN $PHOTON_ROUTER_IP &>/dev/null; then
    echo "Lookup to vcsa.$DOMAIN works!"
else
    echo "Lookup to vcsa.$DOMAIN failed :("
    exit 1
fi
if nslookup $BASE_IP_RANGE.5 $PHOTON_ROUTER_IP &>/dev/null; then
    echo "Lookup to $BASE_IP_RANGE.5 works!"
else
    echo "Lookup to $BASE_IP_RANGE.5 failed :("
    exit 1
fi
