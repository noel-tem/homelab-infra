# Kept apart from stacks/homelab so guest changes never depend on (or disturb) the tailnet
locals {
  # The LAN, the DNS domain and the Proxmox nodes are shared with Ansible
  shared    = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))
  pihole_ip = local.shared.guests.pihole.ip

  # Each node's Proxmox name is also its Tailscale hostname
  nodes = local.shared.nodes
}
