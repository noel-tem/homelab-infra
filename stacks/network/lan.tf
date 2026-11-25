resource "routeros_system_identity" "this" {
  name = "live-laugh-router"
}

resource "routeros_interface_list" "wan" {
  name = "WAN"
}

resource "routeros_interface_list" "lan" {
  name = "LAN"
}

resource "routeros_interface_list_member" "wan" {
  list      = routeros_interface_list.wan.name
  interface = local.wan_port
}

# The firewall only lets in what comes from this list, so the management port has to be on it. Also the trusted
# VLANs (vlans.tf)
resource "routeros_interface_list_member" "lan" {
  for_each = toset(concat(
    [routeros_interface_bridge.lan.name, local.mgmt_port],
    [for name, v in local.vlans : routeros_interface_vlan.vlan[name].name if v.trusted],
  ))
  list      = routeros_interface_list.lan.name
  interface = each.key
}

# VLAN-aware, so it carries the tagged VLANs in vlans.tf alongside the flat LAN, which is untagged VLAN 1 (every
# port's default pvid). Turning this on resets the bridge for a second or two; if that cuts an apply off, apply
# again
resource "routeros_interface_bridge" "lan" {
  name           = "bridge"
  vlan_filtering = true
}

resource "routeros_interface_bridge_port" "lan" {
  for_each  = toset(concat(local.lan_ports, local.wifi_radios))
  bridge    = routeros_interface_bridge.lan.name
  interface = each.key
  pvid      = contains(local.client_ports, each.key) ? local.vlans.clients.id : 1
}

resource "routeros_ip_address" "lan" {
  address   = "${local.router_ip}/${local.lan_prefix}"
  interface = routeros_interface_bridge.lan.name
}

# The ISP's address; the router itself also uses the ISP's DNS servers, so it works even if Pi-hole is down
resource "routeros_ip_dhcp_client" "wan" {
  interface    = local.wan_port
  use_peer_dns = true
  use_peer_ntp = false
}

resource "routeros_ip_pool" "lan" {
  name   = "lan"
  ranges = [local.dhcp_range]
}

resource "routeros_ip_dhcp_server" "lan" {
  name         = "lan"
  interface    = routeros_interface_bridge.lan.name
  address_pool = routeros_ip_pool.lan.name
  lease_time   = "1d"
  # RouterOS 7.25's default; without it every plan tries to clear it
  dynamic_lease_identifiers = "client-mac,client-id"
}

# Clients get Pi-hole for DNS, as they did from the old router
resource "routeros_ip_dhcp_server_network" "lan" {
  address    = local.shared.home_subnet
  gateway    = local.router_ip
  dns_server = [local.shared.guests.pihole.ip]
}

# On the flat LAN's DHCP server, or the one for its vlan
resource "routeros_ip_dhcp_server_lease" "static" {
  for_each    = local.static_leases
  server      = lookup(each.value, "vlan", null) == null ? routeros_ip_dhcp_server.lan.name : routeros_ip_dhcp_server.vlan[each.value.vlan].name
  mac_address = each.value.mac
  address     = each.value.ip
  comment     = each.key
}

# Only answers the router itself, not the LAN; Pi-hole is the LAN's resolver. It does repeat mDNS between the LAN,
# clients and iot, so phones still find the Google speakers to cast to, and the Home Assistant app finds it
resource "routeros_ip_dns" "this" {
  allow_remote_requests = false
  mdns_repeat_ifaces = [
    routeros_interface_bridge.lan.name,
    routeros_interface_vlan.vlan["clients"].name,
    routeros_interface_vlan.vlan["iot"].name,
  ]
}

resource "routeros_system_ntp_client" "this" {
  enabled = true
  servers = ["pool.ntp.org"]
}
