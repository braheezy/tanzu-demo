# Tanzu Lab
Collection of tools to run a small Tanzu cluster locally. The cluster is modeled off [this blog](https://williamlam.com/2020/11/complete-vsphere-with-tanzu-homelab-with-just-32gb-of-memory.html).

# Build
1. Build the base ESXi VM:

       packer build .
2. Deploy ESXi host(s):

       vagrant up
3. Generate hosts file for client VM, so it knows the IP and name of the ESXi host(s):

       ./create-client-hosts.sh
4. Bring up client machine:

       vagrant up client

   This will also:
     - Configure certs and DNS so the `client` VM can interact with ESXi host(s)
     - Deploy a PhotonOS VM to the first ESXi host. This VM will be configured to be a router.
5. Login and bring up Web Console for ESXi host:

       vagrant ssh client
       launchUI
6. Login to the UI as `root` and `Rootpass1!`.
7. Open a VM console to the `router` VM and login (same credentials).
8. Run the configure script:

       bash /tmp/scripts/configure-photon-router.sh
9. Deploy vCenter:

       bash /tmp/scripts/deploy-vcsa.sh
10. Configure vCenter with requirements for Tanzu deployment

       bash /tmp/scripts/configure-vcsa.sh
1. Update client to use vSphere connection for govc instead of ESXi

       echo "export GOVC_URL='https://administrator@vsphere.local:Rootpass1!@vcsa.esxi.test'" | sudo tee -a /etc/profile.d/govc.sh
1. After creating cluster, upgrade VM compatibility of vCLS VM via ESXI host

       vcls=$(govc find vm -name vCLS-*)
       govc vm.upgrade -vm $vcls
1. In vSphere UI,
    - For vCLS VM, disable EVC, then power on
    - Suppress no management network redundancy warning by adding `das.ignoreRedundantNetWarning=true` to Cluster Settings
    - Enable DRS and HA
    - For HA, disable host failover (we only have one)
1. Update router VM to use additional networks:

       govc vm.network.add -vm router.esxi.test -net VDS/Workload
       govc vm.network.add -vm router.esxi.test -net VDS/Frontend
1. Add static routes to allow `client` machine to access additional networks:

       sudo ip route add 10.10.0.0/24 via 192.168.122.2
       sudo ip route add 10.20.0.0/24 via 192.168.122.2
       # Verify the IPs can be pinged now
       ping 10.10.0.1
       ping 10.20.0.1
1.