# Tailscale on every Proxmox node advertises the home LAN; the tailnet fails over between them
resource "tailscale_tailnet_key" "subnet_router" {
  for_each      = local.nodes
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags          = ["tag:homelab"]
  description   = "tofu-subnet-router"
}

moved {
  from = tailscale_tailnet_key.subnet_router
  to   = tailscale_tailnet_key.subnet_router["live-laugh-homelab"]
}

# Read by Ansible when a node needs to join the tailnet, keyed by node name
output "subnet_router_auth_keys" {
  value     = { for node, k in tailscale_tailnet_key.subnet_router : node => k.key }
  sensitive = true
}

# Empty until Ansible joins the node with its key above, so a fresh build is:
# apply (mints the keys), ansible-playbook playbooks/proxmox-host.yml, apply again (approves the routes)
# The trailing dot skips stale duplicates, which Tailscale renames to <node>-1 etc.
data "tailscale_devices" "subnet_router" {
  for_each    = local.nodes
  name_prefix = "${each.key}."
}

locals {
  subnet_routers = {
    for node, d in data.tailscale_devices.subnet_router : node => one(d.devices) if one(d.devices) != null
  }
}

# Approves the advertised routes so they don't need a click in the admin console
resource "tailscale_device_subnet_routes" "subnet_router" {
  for_each  = local.subnet_routers
  device_id = each.value.node_id
  routes    = [local.shared.home_subnet]
}

moved {
  from = tailscale_device_subnet_routes.subnet_router
  to   = tailscale_device_subnet_routes.subnet_router[0]
}

moved {
  from = tailscale_device_subnet_routes.subnet_router[0]
  to   = tailscale_device_subnet_routes.subnet_router["live-laugh-homelab"]
}
