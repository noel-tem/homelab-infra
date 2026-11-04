# Shared by every guest in this stack
locals {
  # Guest IDs/IPs/nodes, the cluster nodes, the LAN and the DNS domain are shared with Ansible
  shared = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))
  nodes  = local.shared.nodes
  guests = local.shared.guests
  # From all.yml rather than ~/.ssh, so a plan on the deployer (which has its own key) matches one run here
  ssh_keys = [local.shared.ssh_public_key]
  # Both Pi-holes, so a container keeps resolving names when either is down
  pihole_ips = [local.guests.pihole.ip, local.guests.pihole2.ip]

  # Template ID per node, since "local" storage isn't shared
  debian_template = { for node, t in proxmox_download_file.debian_13 : node => t.id }
}

# On every node, so a guest can be moved by changing its node in all.yml
resource "proxmox_download_file" "debian_13" {
  for_each           = local.nodes
  node_name          = each.key
  content_type       = "vztmpl"
  datastore_id       = "local"
  url                = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
  checksum           = "4c0c27ca6ceab5ef0b84db57825a00f26157ef1854bafe97297813e1cbe8ecb8cc9c453cab6b3b0efe1ba193a50c47ece1e41d950e411b8730b835b71e9e754b"
  checksum_algorithm = "sha512"
  # The template is already on the host; adopt it instead of failing
  overwrite_unmanaged = true
}

moved {
  from = proxmox_download_file.debian_13
  to   = proxmox_download_file.debian_13["live-laugh-homelab"]
}
