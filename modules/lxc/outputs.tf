output "id" {
  value = proxmox_virtual_environment_container.this.id
}

output "ipv4" {
  value = try(proxmox_virtual_environment_container.this.ipv4[var.interface_name], null)
}