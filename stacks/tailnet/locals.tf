# Kept apart from stacks/homelab so guest changes never depend on (or disturb) the tailnet
locals {
  # The Proxmox host's Tailscale hostname
  node = "live-laugh-homelab"

  # The LAN and the DNS domain are shared with Ansible
  shared    = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))
  pihole_ip = local.shared.guests.pihole.ip
}
