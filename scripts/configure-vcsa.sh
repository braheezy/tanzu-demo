#!/bin/bash

VCSAHostname="vcsa.esxi.test"
VCSAUsername="administrator@vsphere.local"
VCSAPassword="Rootpass1!"
DatacenterName="Tanzu-Datacenter"
DatastoreName="datastore1"
ClusterName="Tanzu-Cluster"
ESXiHostname="esxi-1.esxi.test"
ESXiPassword="Rootpass1!"
VDSName="VDS"
VDSManagementPG="Management"
VDSFrontendPG="Frontend"
VDSWorkloadPG="Workload"
StoragePolicyName="Tanzu-Storage-Policy"
StoragePolicyCategory="WorkloadType"
StoragePolicyTag="Tanzu"

export GOVC_URL=https://$VCSAUsername:$VCSAPassword@$VCSAHostname

# Creating vSphere Datacenter
govc datacenter.create ${DatacenterName}

export GOVC_DATACENTER=${DatacenterName}

# Creating vSphere Cluster
govc cluster.create ${ClusterName}

# Adding ESXi host
govc cluster.add -cluster=${ClusterName} -username=root -password=${ESXiPassword} -hostname ${ESXiHostname} -noverify

# Creating Distributed Virtual Switch
govc dvs.create -dvs=${VDSName} -num-uplink-ports=1

# Creating Distributed Portgroups
govc dvs.create $VDSName
govc dvs.portgroup.add -dvs=${VDSName} -type=ephemeral ${VDSManagementPG}
govc dvs.portgroup.add -dvs=${VDSName} -type=ephemeral ${VDSFrontendPG}
govc dvs.portgroup.add -dvs=${VDSName} -type=ephemeral ${VDSWorkloadPG}

# Add 2nd NIC from host to distributed switch
govc dvs.add -dvs ${VDSName} -pnic vmnic1 ${ESXiHostname}

# Creating vSphere Tag Category and vSphere Tag
govc tags.category.create -t Datastore ${StoragePolicyCategory}
govc tags.create -c ${StoragePolicyCategory} ${StoragePolicyTag}

# Assigning Storage Policy Tag to Datastore
govc tags.attach ${StoragePolicyTag} ./datastore/${DatastoreName}

# Creating Storage Policy
govc storage.policy.create -category $StoragePolicyCategory -tag ${StoragePolicyTag} ${StoragePolicyName}
