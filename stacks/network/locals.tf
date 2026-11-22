# The hAP ax3: the LAN's gateway, DHCP server and Wi-Fi. Kept apart from stacks/homelab so a guest change can
# never take the network down, and never auto-applied by the deployer (README: Router)
locals {
  # The LAN, Pi-hole's address and Home Assistant's are shared with Ansible
  shared = yamldecode(file("${path.module}/../../ansible/group_vars/all.yml"))

  lan_prefix = split("/", local.shared.home_subnet)[1]
  # The router is .1, as the old one was, so nothing on the LAN needs a new gateway
  router_ip = cidrhost(local.shared.home_subnet, 1)

  # ether1 is the WAN (the ISP box, in bridge mode). ether5 is left out of the bridge as an out-of-band
  # management port with the bootstrap's 192.168.88.1/24; Tofu never touches its address
  wan_port    = "ether1"
  mgmt_port   = "ether5"
  lan_ports   = ["ether2", "ether3", "ether4"]
  wifi_radios = ["wifi1", "wifi2"] # wifi1 is 5 GHz, wifi2 2.4 GHz

  # Guests with static addresses sit below .100 (all.yml), so DHCP hands out .100-.254
  dhcp_range = "${cidrhost(local.shared.home_subnet, 100)}-${cidrhost(local.shared.home_subnet, 254)}"

  # Addresses DHCP must keep fixed, by MAC
  static_leases = {
    # Home Assistant OS takes its address by DHCP; the MAC is its network_device in stacks/homelab/homeassistant.tf
    homeassistant = { mac = "02:AF:81:79:C4:10", ip = local.shared.guests.homeassistant.ip }

    # Carried over from the old router's reservations, at the same addresses
    dennis          = { mac = "78:AF:08:66:CC:9F", ip = "192.168.0.58" }
    desktop-qames3t = { mac = "B4:2E:99:FD:DF:DE", ip = "192.168.0.43" }
    dennis-thinkpad = { mac = "50:7B:9D:75:29:1A", ip = "192.168.0.154" } # its wired port
  }
}
