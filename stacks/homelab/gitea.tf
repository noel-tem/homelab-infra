# Self-hosted git; first visit to http://192.168.0.22:3000 runs Gitea's web installer
locals {
    gitea_version = "28.2.0"
    gitea_sha256  = "15681fc615d56611c274f52803fef4d6d5316b620f93b677dd4b831a74e50b9f"
    gitea_url     = "https://dl.gitea.com/gitea/${local.gitea_version}/gitea-${local.gitea_version}-linux-amd64"
    gitea_unit    = <<-EOT
        [Unit]
        Description=Gitea
        After=network.target

        [Service]
        User=git
        Group=git
        WorkingDirectory=/var/lib/gitea
        ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
        Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
        Restart=always

        [Install]
        WantedBy=multi-user.target
    EOT
}

module "gitea" {
    source = "../../modules/lxc"

    name = "gitea"
    vm_id = 106
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

resource "terraform_data" "gitea" {
    triggers_replace = [module.gitea.id, local.gitea_version, local.gitea_unit]
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
            "pct exec ${module.gitea.id} -- sh -c 'command -v git || (apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git curl)'",
            "pct exec ${module.gitea.id} -- sh -c 'id git || adduser --system --shell /bin/bash --group --disabled-password --home /home/git git'",
            "pct exec ${module.gitea.id} -- sh -c 'curl -fsSL -o /tmp/gitea ${local.gitea_url} && echo \"${local.gitea_sha256}  /tmp/gitea\" | sha256sum -c - && install -m 755 /tmp/gitea /usr/local/bin/gitea && rm /tmp/gitea'",
            # The installer writes app.ini, so /etc/gitea stays writable by git until it's run
            "pct exec ${module.gitea.id} -- sh -c 'mkdir -p /var/lib/gitea/custom /var/lib/gitea/data /var/lib/gitea/log /etc/gitea && chown -R git:git /var/lib/gitea /etc/gitea && chmod 750 /var/lib/gitea /etc/gitea'",
            "pct exec ${module.gitea.id} -- sh -c 'echo ${base64encode(local.gitea_unit)} | base64 -d > /etc/systemd/system/gitea.service'",
            "pct exec ${module.gitea.id} -- sh -c 'systemctl daemon-reload && systemctl enable gitea && systemctl restart gitea'",
        ]
    }
}
