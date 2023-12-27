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
6. Login to the UI as `root`
7. Open a VM console to the `router` VM and login
8. Run the configure script:

       bash /tmp/configure-photon-router.sh
