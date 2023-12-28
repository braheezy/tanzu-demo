#!/bin/bash

export GOVC_URL='esxi-1.esxi.test'
export GOVC_USERNAME='root'
export GOVC_PASSWORD='Rootpass1!'
export GOVC_DATASTORE='datastore1'

PhotonRouterVMName="router.esxi.test"
PhotonURL='https://packages.vmware.com/photon/5.0/GA/ova/photon-hw15-5.0-dde71ec57.x86_64.ova'
PhotonOVA="photon-hw15-5.0-dde71ec57.x86_64.ova"

if [ ! -f /tmp/$PhotonOVA ]; then
    wget -P /tmp -q $PhotonURL
fi

# Spec obtained by running `govc import.spec` on existing local OVA.
cat <<EOF > /tmp/ova.spec
{
  "DiskProvisioning": "flat",
  "IPAllocationPolicy": "dhcpPolicy",
  "IPProtocol": "IPv4",
  "NetworkMapping": [
    {
      "Name": "VM Network",
      "Network": ""
    }
  ],
  "Annotation": "This OVA provides a minimal installed profile of PhotonOS.\n\n   Default password for root user is changeme. However user will be prompted to change the password during first login.\n\n        ",
  "MarkAsTemplate": false,
  "PowerOn": true,
  "InjectOvfEnv": false,
  "WaitForIP": true
}
EOF

maintenanceStatus=$(govc host.info -json | jq '.hostSystems[].runtime.inMaintenanceMode')
if [[ $maintenanceStatus == "true" ]];then
  govc host.maintenance.exit $GOVC_URL
fi

govc import.ova \
  -name="${PhotonRouterVMName}" \
  -options /tmp/ova.spec \
  "/tmp/${PhotonOVA}"

guestIP=$(govc vm.ip "$PhotonRouterVMName")

govc host.autostart.configure -enabled
govc host.autostart.add $PhotonRouterVMName

# Now, hack in a new root password :D
expect - <<EOF
set old_password "changeme"
set new_password "Bigaxx3#"

spawn ssh-copy-id -i ~/.ssh/id_ed25519.pub root@$guestIP

expect "Password:"
send "\$old_password\r"

expect "Current password:"
send "\$old_password\r"

expect "New password:"
send "\$new_password\r"

expect "Retype new password:"
send "\$new_password\r"

send "exit"
EOF

# Deploy the configure script to the router. It must be run from VM Console cause SSH will break
if [ -f /tmp/scripts/configure-photon-router.sh ]; then
  scp /tmp/scripts/configure-photon-router.sh root@$guestIP:/tmp/
fi

# Setup easy access
if grep -q "router" /etc/hosts; then
  echo -e "Host router\n\tUser root" >> ~/.ssh/config
  # This is the static IP that will get assigned in configure-photon-router.sh
  echo "192.168.122.2      router" >> /etc/hosts
fi
