# Proxmox HA for every guest with a failover node in ansible/group_vars/all.yml: its disks are replicated there, and
# if its own node goes down HA restarts it there, then moves it back once the node returns (README: High availability)
# Replication is asynchronous, so a failover loses whatever changed since the last sync
locals {
  ha_guests = { for name, g in local.guests : name => g if try(g.failover, null) != null }
  # Containers are ct:<id>, VMs vm:<id>; Home Assistant is the only VM
  ha_vms = ["homeassistant"]
  # How often each guest's disks are copied to its failover node: more often for what changes more and matters more
  ha_replication_schedule = {
    pihole        = "*/5"
    caddy         = "*/15"
    homeassistant = "*/5"
    gitea         = "*/2"
  }
}

resource "proxmox_replication" "ha" {
  for_each = local.ha_guests

  id       = "${each.value.vmid}-0"
  type     = "local"
  target   = each.value.failover
  schedule = lookup(local.ha_replication_schedule, each.key, "*/15")
  # MB/s, so a sync never fills the 1 Gb link that corosync shares
  rate    = 40
  comment = "HA: ${each.key} to ${each.value.failover}"

  lifecycle {
    # Proxmox points the job back at the other node whenever the guest moves (failover or failback), which is what
    # keeps the copy where it'll be needed next; the target here only applies when the job is created
    ignore_changes = [target]
  }
}

resource "proxmox_haresource" "ha" {
  for_each = local.ha_guests

  resource_id = "${contains(local.ha_vms, each.key) ? "vm" : "ct"}:${each.value.vmid}"
  state       = "started"
  # Back to its own node once that's up again
  failback = true
  comment  = "Fails over to ${each.value.failover}"

  # Not before its disks have somewhere to fail over to
  depends_on = [proxmox_replication.ha]
}

# Its own node first, then the failover node; strict, since no other node has a copy of its disks
resource "proxmox_harule" "ha" {
  for_each = local.ha_guests

  rule      = "${each.key}-nodes"
  type      = "node-affinity"
  resources = [proxmox_haresource.ha[each.key].resource_id]
  nodes = {
    (each.value.node)     = 2
    (each.value.failover) = 1
  }
  strict  = true
  comment = "${each.key}: ${each.value.node}, else ${each.value.failover}"
}
