# Self-hosted git; first visit to http://192.168.0.22:3000 runs Gitea's web installer
# Ansible installs and runs Gitea (ansible/roles/gitea)
locals {
    # false shuts the container down (and keeps it down across host reboots); data is kept
    gitea_running = true
}

module "gitea" {
    source = "../../modules/lxc"

    name = "gitea"
    vm_id = 106
    started = local.gitea_running
    start_on_boot = local.gitea_running
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "192.168.0.22/24"
    # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
    dns_servers = ["192.168.0.10"]
    ssh_public_keys = local.ssh_keys
    memory = 1024
    disk_size = 16
    tags = ["dev"]
}
