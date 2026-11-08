# Proxmox Backup Server; the cluster's nightly backups land in its datastore on the M75s's SSD
# Ansible installs and configures it (ansible/roles/pbs) and connects the cluster (ansible/roles/pbs_storage)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  pbs_running = true
}

module "pbs" {
  source = "../../modules/lxc"

  name             = "pbs"
  vm_id            = local.guests.pbs.vmid
  started          = local.pbs_running
  start_on_boot    = local.pbs_running
  node_name        = local.guests.pbs.node
  template_file_id = local.debian_template[local.guests.pbs.node]
  ipv4_address     = "${local.guests.pbs.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  cores           = 2
  memory          = 2048
  disk_size       = 8
  # ssd-lvm is the 1 TB SSD, set up by Ansible (ansible/roles/disk_storage), all of it for the datastore; kept out of backups so PBS doesn't back itself up
  mount_points = [{ volume = "ssd-lvm", size = "930G", path = "/mnt/datastore" }]
  tags         = ["backup"]
}

# Second copy of the backups on live-laugh-nicolekidman, pulled from pbs every morning (ansible/roles/pbs_sync)
# The cluster has it as storage pbs2 for restores only, so it survives losing pbs, its SSD or tomcruise
module "pbs2" {
  source = "../../modules/lxc"

  name             = "pbs2"
  vm_id            = local.guests.pbs2.vmid
  started          = local.pbs_running
  start_on_boot    = local.pbs_running
  node_name        = local.guests.pbs2.node
  template_file_id = local.debian_template[local.guests.pbs2.node]
  ipv4_address     = "${local.guests.pbs2.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  cores           = 2
  memory          = 2048
  disk_size       = 8
  # nicolekidman has no local-lvm, only ZFS
  datastore_id = "local-zfs"
  # hdd-backup is the 1 TB HDD, set up by hand (README: Backups), all of it for the datastore; like pbs's, kept out of backups
  mount_points = [{ volume = "hdd-backup", size = "930G", path = "/mnt/datastore" }]
  tags         = ["backup"]
}
