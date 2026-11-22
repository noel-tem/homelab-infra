# One network on both radios, bridged into the LAN (lan.tf). Same SSID and passphrase as the old router,
# so devices reconnect by themselves after the swap
resource "routeros_wifi_security" "home" {
  name                 = "home"
  authentication_types = ["wpa2-psk", "wpa3-psk"]
  passphrase           = var.wifi_passphrase
  ft                   = true
}

resource "routeros_wifi_configuration" "home" {
  name    = "home"
  mode    = "ap"
  ssid    = var.wifi_ssid
  country = var.wifi_country
  security = {
    config = routeros_wifi_security.home.name
  }
}

# 5 GHz on channel 36 at 80 MHz (36–48, no DFS). Left to itself, RouterOS picked channel 177, which many
# clients (older Intel cards, smart-home gadgets) can't use, so everything stayed on 2.4 GHz
resource "routeros_wifi_channel" "five_ghz" {
  name              = "5ghz"
  band              = "5ghz-ax"
  width             = "20/40/80mhz"
  frequency         = [5180]
  skip_dfs_channels = "all"
}

# The radios come with the router, so Tofu adopts them rather than creating them
import {
  for_each = toset(local.wifi_radios)
  to       = routeros_wifi.radio[each.key]
  id       = "name=${each.key}"
}

resource "routeros_wifi" "radio" {
  for_each = toset(local.wifi_radios)
  name     = each.key
  disabled = !var.wifi_enabled
  configuration = {
    config = routeros_wifi_configuration.home.name
  }
  # wifi1 is the 5 GHz radio (locals.tf); 2.4 GHz keeps RouterOS's automatic choice
  channel = each.key == "wifi1" ? { config = routeros_wifi_channel.five_ghz.name } : null
}
