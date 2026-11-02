# InfluxDB (Proxmox pushes host and guest metrics to it) and Grafana to graph them
# Ansible installs and configures both (ansible/roles/influxdb, ansible/roles/grafana)
locals {
  # false shuts the container down (and keeps it down across host reboots); data is kept
  metrics_running = true
}

module "metrics" {
  source = "../../modules/lxc"

  name             = "metrics"
  vm_id            = local.guests.metrics.vmid
  started          = local.metrics_running
  start_on_boot    = local.metrics_running
  node_name        = local.guests.metrics.node
  template_file_id = local.debian_template[local.guests.metrics.node]
  ipv4_address     = "${local.guests.metrics.ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  memory          = 1536
  disk_size       = 16
  tags            = ["monitoring"]
}
