# Local DNS records served by Pi-hole so LAN clients can reach services by name
locals {
    dns_domain = "home.arpa"
    # Proxied services resolve to Caddy, which forwards to the real host and port
    dns_hosts = { for name, _ in local.proxied_services : name => local.caddy_ip }
}

# Overwrites Pi-hole's whole dns.hosts list, so records added in the web UI get replaced
resource "terraform_data" "pihole_dns_hosts" {
    triggers_replace = [local.dns_hosts, local.dns_domain]
    input = { host = local.proxmox_host }
    # Don't point names at Caddy until it's serving them
    depends_on = [terraform_data.caddy]

    connection {
        type        = "ssh"
        host        = self.input.host
        user        = "root"
        private_key = file(pathexpand("~/.ssh/id_ed25519"))
    }

    provisioner "remote-exec" {
        inline = [
            "pct exec ${module.pihole.id} -- pihole-FTL --config dns.hosts '${jsonencode([for name, ip in local.dns_hosts : "${ip} ${name}.${local.dns_domain}"])}'",
        ]
    }
}
