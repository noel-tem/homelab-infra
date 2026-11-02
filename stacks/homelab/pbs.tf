# Proxmox Backup Server; the cluster's nightly backups land in its datastore on the M75s's HDD
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
  # hdd-lvm is the HDD, set up by Ansible (ansible/roles/hdd_storage); kept out of backups so PBS doesn't back itself up
  mount_points = [{ volume = "hdd-lvm", size = "200G", path = "/mnt/datastore" }]
  tags         = ["backup"]
}
