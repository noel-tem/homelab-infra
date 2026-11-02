locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  pihole_running = true
}

module "pihole" {
  source = "../../modules/lxc"

  name             = "pi-hole"
  vm_id            = local.guests.pihole.vmid
  started          = local.pihole_running
  start_on_boot    = local.pihole_running
  node_name        = local.guests.pihole.node
  template_file_id = local.debian_template[local.guests.pihole.node]
  ipv4_address     = "${local.guests.pihole.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers = local.pihole_ips
  disk_size   = 8
  firewall    = true
}

# Failover for the one above, on the other node; Ansible installs Pi-hole and keeps both configured the same (ansible/roles/pihole)
module "pihole2" {
  source = "../../modules/lxc"

  name             = "pi-hole-2"
  vm_id            = local.guests.pihole2.vmid
  started          = local.pihole_running
  start_on_boot    = local.pihole_running
  node_name        = local.guests.pihole2.node
  template_file_id = local.debian_template[local.guests.pihole2.node]
  ipv4_address     = "${local.guests.pihole2.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  disk_size       = 8
  firewall        = true
}
