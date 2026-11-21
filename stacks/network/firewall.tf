# RouterOS's default firewall: nothing from the WAN reaches the router or the LAN unless the LAN started it
locals {
  # In order; routeros_move_items below keeps them that way
  filter_rules = [
    { key = "input-established", chain = "input", action = "accept", connection_state = "established,related,untracked" },
    { key = "input-invalid", chain = "input", action = "drop", connection_state = "invalid" },
    { key = "input-icmp", chain = "input", action = "accept", protocol = "icmp" },
    { key = "input-not-lan", chain = "input", action = "drop", in_interface_list = "!LAN" },
    { key = "forward-fasttrack", chain = "forward", action = "fasttrack-connection", connection_state = "established,related", hw_offload = true },
    { key = "forward-established", chain = "forward", action = "accept", connection_state = "established,related,untracked" },
    { key = "forward-invalid", chain = "forward", action = "drop", connection_state = "invalid" },
    { key = "forward-wan-not-dstnat", chain = "forward", action = "drop", in_interface_list = "WAN", connection_nat_state = "!dstnat", connection_state = "new" },
  ]
}

resource "routeros_ip_firewall_filter" "rule" {
  for_each = { for r in local.filter_rules : r.key => r }

  chain                = each.value.chain
  action               = each.value.action
  connection_state     = lookup(each.value, "connection_state", null)
  connection_nat_state = lookup(each.value, "connection_nat_state", null)
  protocol             = lookup(each.value, "protocol", null)
  in_interface_list    = lookup(each.value, "in_interface_list", null)
  hw_offload           = lookup(each.value, "hw_offload", null)
  comment              = each.key

  # A drop on !LAN before the management port is on LAN would cut Tofu off mid-apply
  depends_on = [routeros_interface_list_member.lan, routeros_interface_list_member.wan]
}

resource "routeros_move_items" "filter" {
  resource_path = "/ip/firewall/filter"
  sequence      = [for r in local.filter_rules : routeros_ip_firewall_filter.rule[r.key].id]
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

locals {
  mgmt_sources = join(",", [local.shared.home_subnet, "192.168.88.0/24"])

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
