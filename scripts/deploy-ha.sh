#!/bin/bash

set -euo pipefail

HAProxyOVAUrl="https://cdn.haproxy.com/download/haproxy/vsphere/ova/haproxy-v0.2.0.ova"
HAProxyOVA="haproxy-v0.2.0.ova"
DOMAIN="esxi.test"
BASE_IP_RANGE=192.168.122
VMHost="esxi-1.$DOMAIN"
Datastore="datastore1"

HAProxyDisplayName="haproxy.$DOMAIN"
HAProxyHostname="haproxy.$DOMAIN"
HAProxyDNS="$BASE_IP_RANGE.2"
HAProxyManagementNetwork="Management"
HAProxyManagementIPAddress="$BASE_IP_RANGE.6/24"
HAProxyManagementGateway="$BASE_IP_RANGE.1"
HAProxyFrontendNetwork="Frontend"
HAProxyWorkloadNetwork="Workload"
HAProxyWorkloadIPAddress="10.20.0.2/24"
HAProxyWorkloadGateway="10.20.0.1"
HAProxyLoadBalanceIPRange="10.10.0.64/26"
HAProxyPort="5556"
HAProxyUsername="root"
HAProxyPassword="Rootpass1!"

if [ ! -f /tmp/$HAProxyOVA ]; then
    wget -P /tmp -q $HAProxyOVAUrl
fi

tempJSON=$(mktemp)

# spec obtained by running `govc import.spec` on local OVA
cat <<EOF > "$tempJSON"
{
  "Deployment": "frontend",
  "DiskProvisioning": "thin",
  "IPAllocationPolicy": "dhcpPolicy",
  "IPProtocol": "IPv4",
  "PropertyMapping": [
    {
      "Key": "appliance.root_pwd",
      "Value": "$HAProxyPassword"
    },
    {
      "Key": "appliance.permit_root_login",
      "Value": "True"
    },
    {
      "Key": "appliance.ca_cert",
      "Value": ""
    },
    {
      "Key": "appliance.ca_cert_key",
      "Value": ""
    },
    {
      "Key": "network.hostname",
      "Value": "$HAProxyHostname"
    },
    {
      "Key": "network.nameservers",
      "Value": "$HAProxyDNS"
    },
    {
      "Key": "network.management_ip",
      "Value": "$HAProxyManagementIPAddress"
    },
    {
      "Key": "network.management_gateway",
      "Value": "$HAProxyManagementGateway"
    },
    {
      "Key": "network.workload_ip",
      "Value": "$HAProxyWorkloadIPAddress"
    },
    {
      "Key": "network.workload_gateway",
      "Value": "$HAProxyWorkloadGateway"
    },
    {
      "Key": "network.additional_workload_networks",
      "Value": ""
    },
    {
      "Key": "network.frontend_ip",
      "Value": ""
    },
    {
      "Key": "network.frontend_gateway",
      "Value": ""
    },
    {
      "Key": "loadbalance.service_ip_range",
      "Value": "$HAProxyLoadBalanceIPRange"
    },
    {
      "Key": "loadbalance.dataplane_port",
      "Value": "$HAProxyPort"
    },
    {
      "Key": "loadbalance.haproxy_user",
      "Value": "$HAProxyUsername"
    },
    {
      "Key": "loadbalance.haproxy_pwd",
      "Value": "$HAProxyPassword"
    }
  ],
  "NetworkMapping": [
    {
      "Name": "$HAProxyManagementNetwork",
      "Network": ""
    },
    {
      "Name": "$HAProxyWorkloadNetwork",
      "Network": ""
    },
    {
      "Name": "$HAProxyFrontendNetwork",
      "Network": ""
    }
  ],
  "Annotation": "HAProxy for the Load Balancer API (v0.2.0)",
  "MarkAsTemplate": false,
  "PowerOn": false,
  "InjectOvfEnv": false,
  "WaitForIP": false,
  "Name": null
}
EOF

# Deploy HAProxy VM
govc import.ova -options="$tempJSON" -name="$HAProxyDisplayName" -host $VMHost -ds="$Datastore" "/tmp/$HAProxyOVA"

# # Power on the VM
# govc vm.power -on $HAProxyDisplayName

# rm -f "$tempJSON" || exit

# HAProxyIP=$(govc vm.ip $HAProxyDisplayName)

# # Add to SSH config and hosts file
# if grep -q "haproxy" /etc/hosts; then
#     echo -e "Host haproxy\n\tUser root" >> ~/.ssh/config
#     echo "$HAProxyIP      haproxy $HAProxyHostname" >> /etc/hosts
# fi
