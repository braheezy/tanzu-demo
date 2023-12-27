packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = "~> 1"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "32G"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:ff062f843be45760b591096fbf7be0b1003f6469db24f2d2e40a4c8ed3d86c21"
}

variable "iso_url" {
  type    = string
  default = "VMware-VMvisor-Installer-8.0U2-22380479.x86_64.iso"
}

source "qemu" "esxi-amd64-libvirt" {
  accelerator = "kvm"
  boot_command = [
    "<enter>",
    "<wait>",
    "<leftShiftOn>O<leftShiftOff>",
    "<wait>",
    " netdevice=vmnic0",
    " bootproto=dhcp",
    " ks=cdrom:/KS.CFG",
    "<enter>"
  ]
  boot_wait        = "3s"
  cpus              = 4
  disk_discard     = "unmap"
  disk_interface   = "ide"
  disk_size        = var.disk_size
  format           = "qcow2"
  headless         = true
  cd_files         = ["ks.cfg"]
  http_directory   = "."
  iso_checksum     = var.iso_checksum
  iso_url          = var.iso_url
  memory           = 4096
  net_bridge       = "virbr0"
  net_device       = "vmxnet3"
  qemuargs         = [["-cpu", "host"]]
  shutdown_command = "esxcli system maintenanceMode set --enable true; esxcli system shutdown poweroff --reason 'packer shutdown'"
  ssh_password     = "Rootpass1!"
  ssh_timeout      = "60m"
  ssh_username     = "root"
}

build {
  sources = ["source.qemu.esxi-amd64-libvirt"]

  provisioner "shell" {
    pause_before = "10s"
    script       = "scripts/info.sh"
  }

  provisioner "file" {
    source = "scripts/local.sh"
    destination = "/etc/rc.local.d/local.sh"
  }

  provisioner "shell" {
    script = "scripts/sysprep.sh"
  }

  post-processor "vagrant" {
    output               = "{{ .BuildName }}.box"
    vagrantfile_template = "Vagrantfile.template"
  }
}
