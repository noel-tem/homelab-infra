# Self-hosted git; first visit to http://10.42.10.22:3000 runs Gitea's web installer
# Ansible installs and runs Gitea (ansible/roles/gitea)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  gitea_running = true
}

module "gitea" {
  source = "../../modules/lxc"

  name             = "gitea"
  vm_id            = local.guests.gitea.vmid
  started          = local.gitea_running
  start_on_boot    = local.gitea_running
  node_name        = local.guests.gitea.node
  template_file_id = local.debian_template[local.guests.gitea.node]
  ipv4_address     = "${local.guests.gitea.ip}/${local.guest_prefixes.gitea}"
  ipv4_gateway     = local.guest_gateways.gitea
  vlan_id          = local.guest_networks.gitea.vlan_id
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  memory          = 1024
  disk_size       = 16
  tags            = ["dev"]
}
