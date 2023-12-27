ESXI_DOMAIN = 'esxi.test'
MANAGEMENT_CERTIFICATE_PATH = "shared/tls/example-esxi-ca/#{ESXI_DOMAIN}"
DATASTORE_DISK_SIZE_GB = 150
NODE_COUNT = 1

# create the management certificate that will be used to access the esxi
# management web interface (hostd).
def ensure_management_certificate
  return if File.exist?(MANAGEMENT_CERTIFICATE_PATH)
  system("bash provision-certificate.sh #{ESXI_DOMAIN}", exception: true)
end

ensure_management_certificate

Vagrant.configure(2) do |config|

  (1..NODE_COUNT).each do |i|
    config.vm.define "esxi-#{i}" do |node|

      node.vm.provider 'libvirt' do |lv, config|
        lv.default_prefix = ""
        lv.memory = 4*1024
        lv.cpus = 4
        lv.storage :file, :bus => 'ide', :cache => 'unsafe', :size => "#{DATASTORE_DISK_SIZE_GB}G"
      end

      node.vm.box_url = 'esxi-amd64-libvirt.box'
      node.vm.box = 'esxi'
      node.vm.hostname = "esxi-#{i}.#{ESXI_DOMAIN}"

      node.ssh.username = 'root'
      node.ssh.password = 'Rootpass1!'

      # NB you must use `privileged: false` in the provisioning steps because esxi
      #    does not have the `sudo` command, and, by default, you are already
      #    executing commands as root.

      # configure settings.
      node.vm.provision :shell, privileged: false, path: 'scripts/settings.sh'

      # configure the management certificate.
      node.vm.provision :file, source: MANAGEMENT_CERTIFICATE_PATH, destination: '/tmp/tls'
      node.vm.provision :shell, privileged: false, path: 'scripts/management-certs.sh'

      # create the datastore1 datastore in the second disk.
      node.vm.provision :shell, privileged: false, path: 'scripts/datastore.sh'

      # show the installation summary.
#       node.vm.provision "summary", type: "shell", run: "always", privileged: false,
# inline: <<-SCRIPT
# #!/bin/sh
# set -ueo pipefail

# fqdn="$(hostname -f)"
# management_ip_address="$(esxcli --formatter=csv network ip interface ipv4 get -i vmk0 | tail +2 | awk -F, '{print $4}')"

# esxcli system version get

# cat <<EOF

# To access this system, add this host managament IP address to your hosts file:

#     ./create-client-hosts.sh
#     # File contains this for each node
#     $management_ip_address $fqdn

# Trust the example CA:

#     sudo install shared/tls/example-esxi-ca/example-esxi-ca-crt.pem /usr/local/share/ca-certificates/example-esxi-ca.crt
#     sudo update-ca-certificates -v
#     certutil -d sql:\$HOME/.pki/nssdb -A -t 'C,,' -n 'Example ESXi CA' -i shared/tls/example-esxi-ca/example-esxi-ca-crt.pem
#     certutil -d sql:\$HOME/.pki/nssdb -L
#     #certutil -d sql:\$HOME/.pki/nssdb -D -n 'Example ESXi CA' # delete.

# Access the management web interface at:

#     https://$fqdn

# And login with the following user name and password:

#     root
#     Rootpass1!

# EOF

# SCRIPT
    end
  end

  config.vm.define "client", autostart: false, primary: true do |client|
    client.vm.box = 'generic/fedora39'
    client.vm.hostname = "client"

    client.vm.provision :shell, inline: "rm -rf /tmp/tls &>/dev/null || true"

    client.vm.provision :file, source: 'client_hosts_file', destination: '/tmp/'
    client.vm.provision :file, source: MANAGEMENT_CERTIFICATE_PATH, destination: '/tmp/tls'

    client.vm.provision :shell, reboot: true, inline: <<-SCRIPT
      #!/bin/bash
      yum update -y
      yum makecache
      yum install -y firefox xorg-x11-xauth kitty-terminfo nss-tools openssl
    SCRIPT

    client.vm.provision "test", type: "shell", privileged: false, inline: <<-SCRIPT
      #!/bin/bash
      # Add trust for Firefox
      firefox -headless &>/dev/null &
      sleep 2
      pkill firefox
      certDB=$(find  ~/.mozilla* -name "cert9.db")
      certDir=$(dirname ${certDB})
      certutil -A -n "Esxi Test" -t "TCu,Cuw,Tuw" -i /tmp/tls/esxi.test-crt.pem -d sql:$certDir &>/dev/null

      # Add system trust
      # Hacky, but update-ca-trust wasn't working
      sudo bash -c 'cat /tmp/tls/esxi.test-crt.pem >> /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem'

      # Set hosts file
      sudo mv /tmp/client_hosts_file /etc/hosts
    SCRIPT
  end

  config.vm.provider 'libvirt' do |lv, config|
    lv.default_prefix = ""
    lv.memory = 2048
    lv.cpus = 2
  end
  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true
end
