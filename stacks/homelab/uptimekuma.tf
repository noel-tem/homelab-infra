# Uptime checks and alerts; first visit to http://192.168.0.24:3001 creates the admin account
# Ansible installs and runs Uptime Kuma (ansible/roles/uptime_kuma)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  uptimekuma_running = true
}

module "uptimekuma" {
  source = "../../modules/lxc"

  name             = "uptimekuma"
  vm_id            = local.guests.uptimekuma.vmid
  started          = local.uptimekuma_running
  start_on_boot    = local.uptimekuma_running
  node_name        = local.guests.uptimekuma.node
  template_file_id = local.debian_template[local.guests.uptimekuma.node]
  ipv4_address     = "${local.guests.uptimekuma.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = [local.pihole_ip]
  ssh_public_keys = local.ssh_keys
  # npm ci needs the headroom during installs
  memory    = 1024
  disk_size = 8
  tags      = ["monitoring"]
}
