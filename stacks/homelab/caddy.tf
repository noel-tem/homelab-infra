# Reverse proxy so services are reachable at http://<name>.home.arpa without a port
# Ansible installs and configures Caddy (ansible/roles/caddy)
locals {
    caddy_ip = "192.168.0.21"
}

module "caddy" {
    source = "../../modules/lxc"

    name = "caddy"
    vm_id = 105
    node_name = local.node
    template_file_id = local.debian_template
    ipv4_address = "${local.caddy_ip}/24"
    # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
    dns_servers = ["192.168.0.10"]
    ssh_public_keys = local.ssh_keys
    tags = ["proxy"]
}
