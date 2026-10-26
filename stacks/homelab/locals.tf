# Shared by every guest in this stack
locals {
  node            = "live-laugh-homelab"
  debian_template = proxmox_download_file.debian_13.id
  ssh_keys        = [trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))]

  # Guest IDs/IPs, the LAN and the DNS domain are shared with Ansible
  shared    = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))
  guests    = local.shared.guests
  pihole_ip = local.guests.pihole.ip
}

resource "proxmox_download_file" "debian_13" {
  node_name          = local.node
  content_type       = "vztmpl"
  datastore_id       = "local"
  url                = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
  checksum           = "4c0c27ca6ceab5ef0b84db57825a00f26157ef1854bafe97297813e1cbe8ecb8cc9c453cab6b3b0efe1ba193a50c47ece1e41d950e411b8730b835b71e9e754b"
  checksum_algorithm = "sha512"
  # The template is already on the host; adopt it instead of failing
  overwrite_unmanaged = true
}
