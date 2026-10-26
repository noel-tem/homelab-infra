# Media server; first visit to http://192.168.0.23:8096 runs Jellyfin's setup wizard
# Ansible installs and runs Jellyfin (ansible/roles/jellyfin)
module "jellyfin" {
    source = "../../modules/lxc"

    name = "jellyfin"
    vm_id = 107
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "192.168.0.23/24"
    # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
    dns_servers = ["192.168.0.10"]
    ssh_public_keys = local.ssh_keys
    cores = 2
    memory = 2048
    disk_size = 16
    # Separate volume for the library, kept out of the root disk and out of backups
    mount_points = [{ volume = "local-lvm", size = "100G", path = "/mnt/media" }]
    tags = ["media"]
}
