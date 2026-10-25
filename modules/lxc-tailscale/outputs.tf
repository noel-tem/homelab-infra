output "id" {
  value = module.lxc.id
}

output "ipv4" {
  value = module.lxc.ipv4
}

output "tailscale_addresses" {
  value = data.tailscale_device.this.addresses
}
