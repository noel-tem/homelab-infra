# RouterOS's default firewall: nothing from the WAN reaches the router or the LAN unless the LAN started it.
# On top of that, between VLANs: LAN (the flat LAN, the management port and the trusted VLANs) reaches everything,
# and RESTRICTED (media, iot) reaches only the internet and Pi-hole's DNS. Replies always get back
locals {
  pihole_ip = local.shared.guests.pihole.ip

  # In order; routeros_move_items below keeps them that way
  filter_rules = [
    { key = "input-established", chain = "input", action = "accept", connection_state = "established,related,untracked" },
    { key = "input-invalid", chain = "input", action = "drop", connection_state = "invalid" },
    { key = "input-icmp", chain = "input", action = "accept", protocol = "icmp" },
    # RESTRICTED gets DHCP from the router and nothing else of it, except iot's mDNS for the repeater (lan.tf)
    { key = "input-restricted-dhcp", chain = "input", action = "accept", in_interface_list = "RESTRICTED", protocol = "udp", dst_port = "67" },
    { key = "input-iot-mdns", chain = "input", action = "accept", in_interface = "vlan30-iot", protocol = "udp", dst_port = "5353" },
    { key = "input-not-lan", chain = "input", action = "drop", in_interface_list = "!LAN" },
    # No hw_offload: the hAP ax3 has no L3 hardware offload, and RouterOS rejects the parameter on it
    { key = "forward-fasttrack", chain = "forward", action = "fasttrack-connection", connection_state = "established,related" },
    { key = "forward-established", chain = "forward", action = "accept", connection_state = "established,related,untracked" },
    { key = "forward-invalid", chain = "forward", action = "drop", connection_state = "invalid" },
    { key = "forward-wan-not-dstnat", chain = "forward", action = "drop", in_interface_list = "WAN", connection_nat_state = "!dstnat", connection_state = "new" },
    { key = "forward-lan", chain = "forward", action = "accept", in_interface_list = "LAN" },
    { key = "forward-restricted-wan", chain = "forward", action = "accept", in_interface_list = "RESTRICTED", out_interface_list = "WAN" },
    { key = "forward-restricted-dns-udp", chain = "forward", action = "accept", in_interface_list = "RESTRICTED", dst_address = local.pihole_ip, protocol = "udp", dst_port = "53" },
    { key = "forward-restricted-dns-tcp", chain = "forward", action = "accept", in_interface_list = "RESTRICTED", dst_address = local.pihole_ip, protocol = "tcp", dst_port = "53" },
    # Home Assistant controls the TV, which is a client (it runs Jellyfin), so it alone gets through to it
    { key = "forward-ha-tv", chain = "forward", action = "accept", src_address = local.shared.guests.homeassistant.ip, dst_address = local.static_leases.living-room-tv.ip },
  ]
}

resource "routeros_ip_firewall_filter" "rule" {
  for_each = { for r in local.filter_rules : r.key => r }

  chain                = each.value.chain
  action               = each.value.action
  connection_state     = lookup(each.value, "connection_state", null)
  connection_nat_state = lookup(each.value, "connection_nat_state", null)
  protocol             = lookup(each.value, "protocol", null)
  src_address          = lookup(each.value, "src_address", null)
  dst_address          = lookup(each.value, "dst_address", null)
  dst_port             = lookup(each.value, "dst_port", null)
  in_interface         = lookup(each.value, "in_interface", null)
  in_interface_list    = lookup(each.value, "in_interface_list", null)
  out_interface_list   = lookup(each.value, "out_interface_list", null)
  comment              = each.key

  # A drop on !LAN before the management port is on LAN would cut Tofu off mid-apply, and a rule can't name a
  # list that doesn't exist yet
  depends_on = [
    routeros_interface_list_member.lan, routeros_interface_list_member.wan, routeros_interface_list.restricted,
    routeros_interface_vlan.vlan,
  ]
}

# Everything the rules above didn't accept. Its own resource so it's only created after them: new rules go on the
# end of the chain, and a drop that landed before forward-lan would cut the LAN off until the reorder below
resource "routeros_ip_firewall_filter" "forward_drop" {
  chain   = "forward"
  action  = "drop"
  comment = "forward-drop"

  depends_on = [routeros_ip_firewall_filter.rule]
}

resource "routeros_move_items" "filter" {
  resource_path = "/ip/firewall/filter"
  sequence = concat(
    [for r in local.filter_rules : routeros_ip_firewall_filter.rule[r.key].id],
    [routeros_ip_firewall_filter.forward_drop.id],
  )
}

resource "routeros_ip_firewall_nat" "masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = routeros_interface_list.wan.name
  comment            = "lan-to-wan"
}

# No IPv6 until it has a firewall of its own; the old router didn't route it to the LAN either
resource "routeros_ipv6_settings" "this" {
  disable_ipv6 = true
}

# Management only from the LAN side: neighbor discovery and MAC-WinBox on the LAN list,
# and the services that stay on restricted to the LAN and the management port
resource "routeros_ip_neighbor_discovery_settings" "this" {
  discover_interface_list = routeros_interface_list.lan.name
}

resource "routeros_tool_mac_server" "this" {
  allowed_interface_list = routeros_interface_list.lan.name
}

resource "routeros_tool_mac_server_winbox" "this" {
  allowed_interface_list = routeros_interface_list.lan.name
}

# The bandwidth-test server is on by default and logs in with the router's users; nothing here uses it
resource "routeros_tool_bandwidth_server" "this" {
  enabled = false
}

locals {
  mgmt_sources = join(",", concat(
    [local.shared.home_subnet, "192.168.88.0/24"],
    [for v in local.vlans : v.subnet if v.trusted],
  ))

  ip_services = {
    telnet  = { port = 23, disabled = true }
    ftp     = { port = 21, disabled = true }
    www     = { port = 80, disabled = true }
    api     = { port = 8728, disabled = true }
    api-ssl = { port = 8729, disabled = true }
    ssh     = { port = 22, disabled = false }
    winbox  = { port = 8291, disabled = false }
    # What Tofu talks to; the certificate is the bootstrap's
    www-ssl = { port = 443, disabled = false, certificate = "router" }
  }
}

resource "routeros_ip_service" "this" {
  for_each    = local.ip_services
  numbers     = each.key
  port        = each.value.port
  disabled    = each.value.disabled
  address     = each.value.disabled ? null : local.mgmt_sources
  certificate = lookup(each.value, "certificate", null)
}
