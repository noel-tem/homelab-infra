# The whole tailnet policy; edit policy.hujson.tftpl instead of the admin console, which this overwrites
resource "tailscale_acl" "policy" {
  acl = templatefile("${path.module}/policy.hujson.tftpl", {
    lan     = local.shared.home_subnet
    nodes   = { for node, n in local.nodes : node => n.ip }
    pihole  = local.shared.guests.pihole.ip
    pihole2 = local.shared.guests.pihole2.ip
    # The address the names point at, whichever Caddy holds it
    caddy = local.shared.caddy_vip
  })
}

# Adopts the policy that was already live instead of refusing to touch it
import {
  to = tailscale_acl.policy
  id = "acl"
}
