# The whole tailnet policy; edit policy.hujson.tftpl instead of the admin console, which this overwrites
resource "tailscale_acl" "policy" {
  acl = templatefile("${path.module}/policy.hujson.tftpl", {
    lan     = local.shared.home_subnet
    proxmox = local.shared.proxmox_host
    pihole  = local.pihole_ip
    caddy   = local.shared.guests.caddy.ip
  })
}

# Adopts the policy that was already live instead of refusing to touch it
import {
  to = tailscale_acl.policy
  id = "acl"
}
