# Sonarr, Radarr, Prowlarr, FlareSolverr, Bazarr, Seerr, and qBittorrent behind Surfshark, in Docker Compose
# Ansible gives it the media and /dev/net/tun (root@pam only) and runs the stack (ansible/roles/arr)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  arr_running = false
}

module "arr" {
  source = "../../modules/lxc"

  name             = "arr"
  vm_id            = local.guests.arr.vmid
  started          = local.arr_running
  start_on_boot    = local.arr_running
  node_name        = local.guests.arr.node
  template_file_id = local.debian_template[local.guests.arr.node]
  ipv4_address     = "${local.guests.arr.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  cores           = 4
  memory          = 4096
  # Docker images plus the apps' databases
  disk_size = 32
  tags      = ["media"]
}
