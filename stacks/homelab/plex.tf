resource "proxmox_virtual_environment_container" "plex" {
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
  unprivileged                         = false
  vm_id                                = null
  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }
  cpu {
    architecture = "amd64"
    cores        = 2
    limit        = 0
  }
  disk {
    acl           = false
    datastore_id  = "local-lvm"
    mount_options = []
    quota         = false
    replicate     = false
    size          = 32
  }
  initialization {
    hostname   = "plex"
    ip_config {
      ipv4 {
        address = "192.168.0.14/24"
        gateway = "192.168.0.1"
      }
      ipv6 {
        address = "dhcp"
        gateway = ""
      }
    }
  }
  memory {
    dedicated = 4096
    swap      = 0
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/mnt/media"
    quota         = false
    read_only     = false
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/srv/media"
  }
  network_interface {
    bridge       = "vmbr0"
    firewall     = false
    host_managed = false
    mac_address  = "BC:24:11:8A:31:E0"
    mtu          = 0
    name         = "etho0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = ""
    type             = "debian"
  }
    lifecycle {
    ignore_changes = [mount_point]
  }
}