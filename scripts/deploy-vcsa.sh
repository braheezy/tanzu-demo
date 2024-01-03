#!/bin/bash

set -eou pipefail

if [ ! -d /mnt/iso/vcsa-cli-installer/lin64/ ];then
    mkdir -p /mnt/iso
    mount -o loop /dev/sr0 /mnt/iso
fi

tempJSON=$(mktemp)

cat <<'EOF' > "$tempJSON"
{
    "__version": "2.13.0",
    "new_vcsa": {
        "esxi": {
            "hostname": "esxi-1.esxi.test",
            "username": "root",
            "password": "Rootpass1!",
            "deployment_network": "VM Network",
            "datastore": "datastore1"
        },
        "appliance": {
            "thin_disk_mode": true,
            "deployment_option": "tiny",
            "name": "vcsa.esxi.test"
        },
        "network": {
            "ip_family": "ipv4",
            "mode": "static",
            "system_name": "vcsa.esxi.test",
            "ip": "192.168.122.5",
            "prefix": "24",
            "gateway": "192.168.122.1",
            "dns_servers": [
                "192.168.122.2"
            ]
        },
        "os": {
            "password": "Rootpass1!",
            "ntp_servers": "pool.ntp.org",
            "ssh_enable": true
        },
        "sso": {
            "password": "Rootpass1!",
            "domain_name": "vsphere.local"
        }
    },
    "ceip": {
        "settings": {
            "ceip_enabled": false
        }
    }
}
EOF

pushd /mnt/iso/vcsa-cli-installer/lin64/ &>/dev/null || exit
    ./vcsa-deploy install \
        --accept-eula \
        --acknowledge-ceip \
        --no-ssl-certificate-verification \
        "$tempJSON"

    rm "$tempJSON"
popd &>/dev/null

# Enable autostart
govc host.autostart.add vcsa.esxi.test

# Add to SSH config and hosts file
if grep -q "vcsa" /etc/hosts; then
    echo -e "Host vcsa\n\tUser root" >> ~/.ssh/config
    echo "192.168.122.5      vcsa vcsa.esxi.test" >> /etc/hosts
fi

# Add generated self-signed certs to system trust
if [ ! -f /etc/pki/ca-trust/source/anchors/vcsa.crt ]; then
    wget --no-check-certificate https://vcsa/certs/download.zip
    unzip download.zip
    sudo cp certs/lin/*.0 /etc/pki/ca-trust/source/anchors/vcsa.crt
    sudo update-ca-trust extract
fi

# SSH over and change default shell from Appliancesh to Bash
expect - <<EOF
set password "Rootpass1!"

spawn ssh vcsa

expect "Password:"
send "\$password\r"

expect "Command>"
send "shell\r"

send "chsh -s /bin/bash\r"

send "exit"

send "exit"

spawn ssh-copy-id -i ~/.ssh/id_ed25519.pub vcsa

expect "Password:"
send "\$password\r"
EOF

# Allow running tanzu with 1 supervisor node
ssh vcsa "sed -i 's/minmasters: 3/minmasters: 1/g' /etc/vmware/wcp/wcpsvc.yaml"
ssh vcsa "sed -i 's/maxmasters: 3/maxmasters: 1/g' /etc/vmware/wcp/wcpsvc.yaml"
# Disables the vCenter Network Rollback feature to allow for a single NIC VDS configuration
ssh vcsa "sed -i 's^<rollback>true</rollback>^<rollback>false</rollback>^g' /etc/vmware-vpx/vpxd.cfg"

# Reduce memory now that it's installed
govc vm.power -off vcsa.esxi.test
# Reduce 14GB -> 10GB
govc vm.change -vm vcsa.esxi.test -m 10240
govc vm.power -on vcsa.esxi.test
