module "plex" {
    source = "../../modules/lxc"

    name = "plex"
    vm_id = 101
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "192.168.0.14/24"
    ipv6_address = "dhcp"
    unprivileged = false
    nesting = false
    cores = 2
    memory = 4096
    swap = 0
    disk_size = 32
    interface_name = "etho0"
    mount_points = [{ volume = "/srv/media", path = "/mnt/media" }]
}

# Reached through the subnet router now, so it no longer runs tailscale itself
moved {
    from = module.plex.module.lxc.proxmox_virtual_environment_container.this
    to   = module.plex.proxmox_virtual_environment_container.this
}
