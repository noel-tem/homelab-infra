module "pihole" {
    source = "../../modules/lxc"

    name = "pi-hole"
    vm_id = 100
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "192.168.0.10/24"
    ipv6_address = "dhcp"
    disk_size = 8
    firewall = true
}