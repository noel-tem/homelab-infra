locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  mosquitto_running = true
}

module "mosquitto" {
  source = "../../modules/lxc"

  name             = "mosquitto"
  vm_id            = local.guests.mosquitto.vmid
  started          = local.mosquitto_running
  start_on_boot    = local.mosquitto_running
  node_name        = local.node
  template_file_id = local.debian_template
  ipv4_address     = "${local.guests.mosquitto.ip}/24"
  ssh_public_keys  = local.ssh_keys
  tags             = ["telemetry"]
}