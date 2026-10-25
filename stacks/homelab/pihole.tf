resource "proxmox_virtual_environment_container" "pihole" {
  delete_unreferenced_disks_on_destroy = false
  description                          = ""
  environment_variables                = {}
  hook_script_file_id                  = ""
  migrate                              = false
  node_name                            = "live-laugh-homelab"
  pool_id                              = null
  protection                           = false
  purge_on_destroy                     = true
  start_on_boot                        = true
  started                              = true
  tags                                 = []
  template                             = false
  timeout_clone                        = 1800
  timeout_create                       = 1800
  timeout_delete                       = 60
  timeout_migrate                      = 1800
  timeout_update                       = 1800
  unprivileged                         = true
  vm_id                                = null
  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }
  disk {
    acl           = false
    datastore_id  = "local-lvm"
    mount_options = []
    quota         = false
    replicate     = false
    size          = 8
  }
  features {
    fuse    = false
    keyctl  = false
    mknod   = false
    mount   = []
    nesting = true
  }
  initialization {
    hostname   = "pi-hole"
    ip_config {
      ipv4 {
        address = "192.168.0.10/24"
        gateway = "192.168.0.1"
      }
      ipv6 {
        address = "dhcp"
        gateway = ""
      }
    }
  }
  memory {
    dedicated = 512
    swap      = 512
  }
  network_interface {
    bridge       = "vmbr0"
    firewall     = true
    host_managed = false
    mac_address  = "BC:24:11:6D:C9:1C"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = ""
    type             = "debian"
  }
}