# Ansible installs and runs Jellyfin (ansible/roles/jellyfin)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  jellyfin_running = true
}

module "jellyfin" {
  source = "../../modules/lxc"

  name             = "jellyfin"
  vm_id            = local.guests.jellyfin.vmid
  started          = local.jellyfin_running
  start_on_boot    = local.jellyfin_running
  node_name        = local.guests.jellyfin.node
  template_file_id = local.debian_template[local.guests.jellyfin.node]
  ipv4_address     = "${local.guests.jellyfin.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  cores           = 2
  memory          = 2048
  disk_size       = 16
  # The media on the 2 TB HDD is a bind mount shared with arr, which only root@pam can set, so Ansible adds it (ansible/roles/media_mount)
  tags = ["media"]
}
