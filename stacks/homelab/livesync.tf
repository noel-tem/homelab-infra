# CouchDB for Obsidian's Self-hosted LiveSync plugin, in Docker Compose
# Ansible installs and runs it (ansible/roles/livesync); no HA, since every synced device holds a full copy of the vault
locals {
  # Set with running in ansible/group_vars/all.yml, which the playbook reads too; false shuts the container
  # down (and keeps it down across host reboots); data is kept
  livesync_running = try(local.guests.livesync.running, true)
}

module "livesync" {
  source = "../../modules/lxc"

  name             = "livesync"
  vm_id            = local.guests.livesync.vmid
  started          = local.livesync_running
  start_on_boot    = local.livesync_running
  node_name        = local.guests.livesync.node
  template_file_id = local.debian_template[local.guests.livesync.node]
  ipv4_address     = "${local.guests.livesync.ip}/${local.guest_prefixes.livesync}"
  ipv4_gateway     = local.guest_gateways.livesync
  vlan_id          = local.guest_networks.livesync.vlan_id
  # tomcruise's root is on ZFS, so it has no local-lvm
  datastore_id = "local-zfs"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  memory          = 1024
  # The Docker image plus the database, which keeps every note's history and attachments until compacted
  disk_size = 16
  tags      = ["notes"]
}
