# Runs tailscale on the Proxmox host and advertises the home LAN to the tailnet
locals {
    home_subnet = "192.168.0.0/24"
}

resource "tailscale_tailnet_key" "subnet_router" {
    reusable      = false
    ephemeral     = false
    preauthorized = true
    expiry        = 3600
    tags          = ["tag:homelab"]
    description   = "tofu-subnet-router"
}

resource "terraform_data" "subnet_router" {
    triggers_replace = [tailscale_tailnet_key.subnet_router.id, local.home_subnet]
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
            "echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf",
            "sysctl -p /etc/sysctl.d/99-tailscale.conf",
            "command -v tailscale || curl -fsSL https://tailscale.com/install.sh | sh",
            "tailscale up --auth-key=${tailscale_tailnet_key.subnet_router.key} --hostname=${local.node} --advertise-routes=${local.home_subnet}",
        ]
    }

    provisioner "remote-exec" {
        when       = destroy
        on_failure = continue
        inline     = ["tailscale logout || true"]
    }
}

data "tailscale_device" "subnet_router" {
    hostname   = local.node
    wait_for   = "60s"
    depends_on = [terraform_data.subnet_router]
}

# Approves the advertised route so it doesn't need a click in the admin console
resource "tailscale_device_subnet_routes" "subnet_router" {
    device_id = data.tailscale_device.subnet_router.node_id
    routes    = [local.home_subnet]
}
