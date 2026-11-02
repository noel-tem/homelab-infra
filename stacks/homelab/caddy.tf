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
  node_name        = local.guests.caddy.node
  template_file_id = local.debian_template[local.guests.caddy.node]
  ipv4_address     = "${local.guests.caddy.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  tags            = ["proxy"]
}

# Failover for the one above, on the other node; Ansible configures both the same and keepalived moves caddy_vip between them
module "caddy2" {
  source = "../../modules/lxc"

  name             = "caddy-2"
  vm_id            = local.guests.caddy2.vmid
  started          = local.caddy_running
  start_on_boot    = local.caddy_running
  node_name        = local.guests.caddy2.node
  template_file_id = local.debian_template[local.guests.caddy2.node]
  ipv4_address     = "${local.guests.caddy2.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  tags            = ["proxy"]
}
