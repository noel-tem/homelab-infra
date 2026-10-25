resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  unprivileged  = var.unprivileged
  started       = var.started
  start_on_boot = var.start_on_boot
  tags          = concat(["tofu"], var.tags)

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_address == "dhcp" ? null : var.ipv4_gateway
      }

      dynamic "ipv6" {
        for_each = var.ipv6_address == null ? [] : [1]
        content {
          address = var.ipv6_address
        }
      }
    }

    dynamic "user_account" {
      for_each = length(var.ssh_public_keys) > 0 ? [1] : []
      content {
        keys = var.ssh_public_keys
      }
    }
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  network_interface {
    name     = var.interface_name
    bridge   = "vmbr0"
    firewall = var.firewall
  }

  # Omitted when nesting is off: privileged containers only accept features from root@pam
  dynamic "features" {
    for_each = var.nesting ? [1] : []
    content {
      nesting = true
    }
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume = mount_point.value.volume
      path   = mount_point.value.path
      backup = mount_point.value.backup
    }
  }

  dynamic "device_passthrough" {
    for_each = var.device_passthrough
    content {
      path = device_passthrough.value
    }
  }

  lifecycle {
    # Updating the template later shouldn't rebuild existing containers
    ignore_changes = [operating_system[0].template_file_id]
  }
}