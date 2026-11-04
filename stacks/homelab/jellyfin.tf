# Ansible installs and runs Jellyfin (ansible/roles/jellyfin)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  jellyfin_running = false
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
  # Separate volume for the library taking up all of the 2 TB HDD (ansible/roles/disk_storage), kept out of the root disk and out of backups
  mount_points = [{ volume = "hdd-lvm", size = "1863G", path = "/mnt/media" }]
  tags         = ["media"]
}
