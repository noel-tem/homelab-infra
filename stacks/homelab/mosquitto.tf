locals {
    node = "live-laugh-homelab"
    debian_template = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
    ssh_keys = [trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))]
}

module "mosquitto" {
    source = "../../modules/lxc"
    
    name = "mosquitto"
    vm_id = 104
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "192.168.0.20/24"
    ssh_public_keys = local.ssh_keys
    tags = ["telemetry"]
}

output "mosquitto_ip" {
    value = module.mosquitto.ipv4
}