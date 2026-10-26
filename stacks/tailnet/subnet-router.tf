# Tailscale on the Proxmox host advertises the home LAN to the tailnet
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

# Empty until Ansible joins the host with the key above, so a fresh build is:
# apply (mints the key), ansible-playbook playbooks/proxmox-host.yml, apply again (approves the route)
# The trailing dot skips stale duplicates, which Tailscale renames to <node>-1 etc.
data "tailscale_devices" "subnet_router" {
  name_prefix = "${local.node}."
}

locals {
  subnet_router = one(data.tailscale_devices.subnet_router.devices)
}

# Approves the advertised route so it doesn't need a click in the admin console
resource "tailscale_device_subnet_routes" "subnet_router" {
  count     = local.subnet_router == null ? 0 : 1
  device_id = local.subnet_router.node_id
  routes    = [local.shared.home_subnet]
}

moved {
  from = tailscale_device_subnet_routes.subnet_router
  to   = tailscale_device_subnet_routes.subnet_router[0]
}
