locals {
    # false shuts the container down (and keeps it down across host reboots); data is kept
    mosquitto_running = true
}

module "mosquitto" {
    source = "../../modules/lxc"

    name = "mosquitto"
    vm_id = 104
    started = local.mosquitto_running
    start_on_boot = local.mosquitto_running
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "192.168.0.20/24"
    ssh_public_keys = local.ssh_keys
    tags = ["telemetry"]
}