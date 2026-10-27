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
  node_name        = local.node
  template_file_id = local.debian_template
  ipv4_address     = "${local.guests.jellyfin.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = [local.pihole_ip]
  ssh_public_keys = local.ssh_keys
  cores           = 2
  memory          = 2048
  disk_size       = 16
  # Separate volume for the library, kept out of the root disk and out of backups
  mount_points = [{ volume = "local-lvm", size = "40G", path = "/mnt/media" }]
  tags         = ["media"]
}
