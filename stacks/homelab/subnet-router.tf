# Tailscale on the Proxmox host advertises the home LAN to the tailnet
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

# Read by Ansible when the host needs to join the tailnet
output "subnet_router_auth_key" {
    value     = tailscale_tailnet_key.subnet_router.key
    sensitive = true
}

data "tailscale_device" "subnet_router" {
    hostname   = local.node
    wait_for = "60s"
}

# Approves the advertised route so it doesn't need a click in the admin console
resource "tailscale_device_subnet_routes" "subnet_router" {
    device_id = data.tailscale_device.subnet_router.node_id
    routes    = [local.home_subnet]
}
