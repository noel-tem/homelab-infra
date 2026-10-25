# Reverse proxy so services are reachable at http://<name>.home.arpa without a port
locals {
    caddy_ip = "192.168.0.21"
    proxied_services = {
        plex          = "192.168.0.14:32400"
        pihole        = "192.168.0.10:80"
        homeassistant = "192.168.0.83:8123"
        gitea         = "192.168.0.22:3000"
    }
    # http:// prefix keeps Caddy from trying to get certificates
    caddyfile = join("\n", [for name, upstream in local.proxied_services : "http://${name}.${local.dns_domain} {\n\treverse_proxy ${upstream}\n}\n"])
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

resource "terraform_data" "caddy" {
    triggers_replace = [module.caddy.id, local.caddyfile]
    input = { host = local.proxmox_host }

    connection {
        type        = "ssh"
        host        = self.input.host
        user        = "root"
        private_key = file(pathexpand("~/.ssh/id_ed25519"))
    }

    provisioner "remote-exec" {
        inline = [
            "set -e",
            "pct exec ${module.caddy.id} -- sh -c 'command -v caddy || (apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y caddy)'",
            "pct exec ${module.caddy.id} -- sh -c 'echo ${base64encode(local.caddyfile)} | base64 -d > /etc/caddy/Caddyfile'",
            "pct exec ${module.caddy.id} -- systemctl reload-or-restart caddy",
        ]
    }
}
