# Kept out of the repo, which is mirrored to public GitHub; set them in .env (README: Prerequisites)

# https://192.168.88.1 (the management port) while the hAP is staged, https://192.168.0.1 once it's the router
variable "router_url" {
  type = string
}

variable "router_username" {
  type    = string
  default = "tofu"
}

variable "router_password" {
  type      = string
  sensitive = true
}

variable "wifi_ssid" {
  type = string
}

variable "wifi_passphrase" {
  type      = string
  sensitive = true
}

variable "wifi_country" {
  type        = string
  description = "RouterOS's country name, e.g. \"United States\"; sets the allowed channels and power"
}

# Off while the hAP is staged next to the old router, so clients can't join a network with no internet (README: Router)
variable "wifi_enabled" {
  type    = bool
  default = true
}
