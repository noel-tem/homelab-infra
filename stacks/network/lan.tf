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

# The firewall only lets in what comes from this list, so the management port has to be on it
resource "routeros_interface_list_member" "lan" {
  for_each  = toset([routeros_interface_bridge.lan.name, local.mgmt_port])
  list      = routeros_interface_list.lan.name
  interface = each.key
}

resource "routeros_interface_bridge" "lan" {
  name = "bridge"
}

resource "routeros_interface_bridge_port" "lan" {
  for_each  = toset(concat(local.lan_ports, local.wifi_radios))
  bridge    = routeros_interface_bridge.lan.name
  interface = each.key
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
}

# Clients get Pi-hole for DNS, as they did from the old router
resource "routeros_ip_dhcp_server_network" "lan" {
  address    = local.shared.home_subnet
  gateway    = local.router_ip
  dns_server = [local.shared.guests.pihole.ip]
}

resource "routeros_ip_dhcp_server_lease" "static" {
  for_each    = local.static_leases
  server      = routeros_ip_dhcp_server.lan.name
  mac_address = each.value.mac
  address     = each.value.ip
  comment     = each.key
}

# Only answers the router itself, not the LAN; Pi-hole is the LAN's resolver
resource "routeros_ip_dns" "this" {
  allow_remote_requests = false
}

resource "routeros_system_ntp_client" "this" {
  enabled = true
  servers = ["pool.ntp.org"]
}
