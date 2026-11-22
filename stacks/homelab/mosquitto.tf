locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  mosquitto_running = false
}

module "mosquitto" {
  source = "../../modules/lxc"

  name             = "mosquitto"
  vm_id            = local.guests.mosquitto.vmid
  started          = local.mosquitto_running
  start_on_boot    = local.mosquitto_running
  node_name        = local.guests.mosquitto.node
  template_file_id = local.debian_template[local.guests.mosquitto.node]
  ipv4_address     = "${local.guests.mosquitto.ip}/${local.guest_prefixes.mosquitto}"
  ipv4_gateway     = local.guest_gateways.mosquitto
  vlan_id          = local.guest_networks.mosquitto.vlan_id
  ssh_public_keys  = local.ssh_keys
  tags             = ["telemetry"]
}