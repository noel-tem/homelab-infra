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
  ipv6_address     = "dhcp"
  disk_size        = 8
  firewall         = true
}