# CI, split so infra credentials never meet unapproved code (README: CI)
# runner: Gitea Actions runner for Claude and lint jobs; holds no infra credentials (ansible/roles/gitea_runner, claude_code)
# deployer: pulls main and applies it; not a runner, so no workflow can reach it (ansible/roles/deployer)
locals {
  # false shuts the containers down (and keeps them down across host reboots); data is kept
  ci_running = true
  ci_guests = {
    runner   = { memory = 2048, disk_size = 16 }
    deployer = { memory = 2048, disk_size = 8 }
  }
}

module "ci" {
  source   = "../../modules/lxc"
  for_each = local.ci_guests

  name             = each.key
  vm_id            = local.guests[each.key].vmid
  started          = local.ci_running
  start_on_boot    = local.ci_running
  node_name        = local.guests[each.key].node
  template_file_id = local.debian_template[local.guests[each.key].node]
  ipv4_address     = "${local.guests[each.key].ip}/24"
  # The host's resolv.conf points at Tailscale's resolver, which containers can't reach
  dns_servers     = local.pihole_ips
  ssh_public_keys = local.ssh_keys
  cores           = 2
  memory          = each.value.memory
  disk_size       = each.value.disk_size
  tags            = ["ci"]
}
