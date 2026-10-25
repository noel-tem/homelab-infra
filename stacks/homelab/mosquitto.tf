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