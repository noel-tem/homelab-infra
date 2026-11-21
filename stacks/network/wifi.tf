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
}
