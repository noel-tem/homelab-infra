# Kept apart from stacks/homelab so guest changes never depend on (or disturb) the tailnet
locals {
  # The LAN, the DNS domain and the Proxmox nodes are shared with Ansible
  shared = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))
  # Both Pi-holes, so *.home.arpa keeps resolving when either is down
  pihole_ips = [local.shared.guests.pihole.ip, local.shared.guests.pihole2.ip]

  # Each node's Proxmox name is also its Tailscale hostname
  nodes = local.shared.nodes
}
