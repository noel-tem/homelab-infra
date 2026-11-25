# Kept apart from stacks/homelab so guest changes never depend on (or disturb) the tailnet
locals {
  # The LAN, the DNS domain and the Proxmox nodes are shared with Ansible
  shared = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))
  # The Pi-hole that answers *.home.arpa
  pihole_ips = [local.shared.guests.pihole.ip]

  # What the subnet routers advertise (tailnet_vlans in all.yml); roles/subnet_router builds the same list
  routes = concat([local.shared.home_subnet], [for v in local.shared.tailnet_vlans : local.shared.vlans[v].subnet])

  # Each node's Proxmox name is also its Tailscale hostname
  nodes = local.shared.nodes
}
