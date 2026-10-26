# Reverse proxy so services are reachable at http://<name>.home.arpa without a port
# Ansible installs and configures Caddy (ansible/roles/caddy)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  caddy_running = true
}

module "caddy" {
  source = "../../modules/lxc"

  name             = "caddy"
  vm_id            = local.guests.caddy.vmid
  started          = local.caddy_running
  start_on_boot    = local.caddy_running
  node_name        = local.node
  template_file_id = local.debian_template
  ipv4_address     = "${local.guests.caddy.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = [local.pihole_ip]
  ssh_public_keys = local.ssh_keys
  tags            = ["proxy"]
}
