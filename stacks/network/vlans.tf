# The VLANs in all.yml, routed by the hAP. They sit on the same bridge as the flat LAN in lan.tf, which stays
# untagged VLAN 1 until everything has moved off it (README: VLANs)
locals {
  # trusted: on the LAN interface list, so it reaches every VLAN, the internet and the router's management. The
  # rest reach only the internet and Pi-hole's DNS (firewall.tf). dhcp: the router hands out addresses there;
  # services and media guests all have static ones
  vlan_policy = {
    services = { trusted = true, dhcp = false }
    media    = { trusted = false, dhcp = false }
    iot      = { trusted = false, dhcp = true }
    clients  = { trusted = true, dhcp = true }
  }

  vlans = {
    for name, v in local.shared.vlans : name => merge(v, local.vlan_policy[name], {
      interface = "vlan${v.id}-${name}"
      gateway   = cidrhost(v.subnet, 1)
      prefix    = split("/", v.subnet)[1]
    })
  }
  dhcp_vlans = { for name, v in local.vlans : name => v if v.dhcp }

  # Where the VLANs leave the hAP tagged: the GS305E's uplink. The other ports stay untagged on VLAN 1
  trunk_ports = ["ether2"]
}

# Tagged on the bridge itself too, so the router's own VLAN interfaces see the traffic
resource "routeros_interface_bridge_vlan" "vlan" {
  for_each = local.vlans
  bridge   = routeros_interface_bridge.lan.name
  vlan_ids = [tostring(each.value.id)]
  tagged   = concat([routeros_interface_bridge.lan.name], local.trunk_ports)
  comment  = each.key
}

resource "routeros_interface_vlan" "vlan" {
  for_each  = local.vlans
  name      = each.value.interface
  interface = routeros_interface_bridge.lan.name
  vlan_id   = each.value.id
}

resource "routeros_ip_address" "vlan" {
  for_each  = local.vlans
  address   = "${each.value.gateway}/${each.value.prefix}"
  interface = routeros_interface_vlan.vlan[each.key].name
}

resource "routeros_interface_list" "restricted" {
  name = "RESTRICTED"
}

resource "routeros_interface_list_member" "restricted" {
  for_each  = { for name, v in local.vlans : name => v if !v.trusted }
  list      = routeros_interface_list.restricted.name
  interface = routeros_interface_vlan.vlan[each.key].name
}

# DHCP as on the flat LAN: .100-.254, Pi-hole for DNS
resource "routeros_ip_pool" "vlan" {
  for_each = local.dhcp_vlans
  name     = each.key
  ranges   = ["${cidrhost(each.value.subnet, 100)}-${cidrhost(each.value.subnet, 254)}"]
}

resource "routeros_ip_dhcp_server" "vlan" {
  for_each                  = local.dhcp_vlans
  name                      = each.key
  interface                 = routeros_interface_vlan.vlan[each.key].name
  address_pool              = routeros_ip_pool.vlan[each.key].name
  lease_time                = "1d"
  dynamic_lease_identifiers = "client-mac,client-id"
}

resource "routeros_ip_dhcp_server_network" "vlan" {
  for_each   = local.dhcp_vlans
  address    = each.value.subnet
  gateway    = each.value.gateway
  dns_server = [local.shared.guests.pihole.ip]
}
