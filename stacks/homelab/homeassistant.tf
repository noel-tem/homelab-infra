resource "proxmox_virtual_environment_vm" "homeassistant" {
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "<div align='center'>\n  <a href='https://community-scripts.org' target='_blank' rel='noopener noreferrer'>\n    <img src='https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/images/logo-81x112.png' alt='Logo' style='width:81px;height:112px;'/>\n  </a>\n\n  <h2 style='font-size: 24px; margin: 20px 0;'>Homeassistant OS VM</h2>\n\n  <p style='margin: 16px 0;'>\n    <a href='https://ko-fi.com/community_scripts' target='_blank' rel='noopener noreferrer'>\n      <img src='https://img.shields.io/badge/&#x2615;-Buy us a coffee-blue' alt='spend Coffee' />\n    </a>\n  </p>\n\n  <span style='margin: 0 10px;'>\n    <i class=\"fa fa-github fa-fw\" style=\"color: #f5f5f5;\"></i>\n    <a href='https://github.com/community-scripts/ProxmoxVE' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>GitHub</a>\n  </span>\n  <span style='margin: 0 10px;'>\n    <i class=\"fa fa-comments fa-fw\" style=\"color: #f5f5f5;\"></i>\n    <a href='https://github.com/community-scripts/ProxmoxVE/discussions' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Discussions</a>\n  </span>\n  <span style='margin: 0 10px;'>\n    <i class=\"fa fa-exclamation-circle fa-fw\" style=\"color: #f5f5f5;\"></i>\n    <a href='https://github.com/community-scripts/ProxmoxVE/issues' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Issues</a>\n  </span>\n</div>"
  hook_script_file_id                  = ""
  hotplug                              = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = ""
  mac_addresses                        = ["00:00:00:00:00:00", "02:AF:81:79:C4:10", "CA:1B:86:51:9F:1B", "32:5F:5C:59:46:6D", "E2:FD:88:BC:BF:22", "7E:31:59:C1:3E:2A", "BA:D3:84:EE:A6:25", "5E:0B:45:A0:31:84", "46:C4:D4:F9:A8:C9", "1E:68:0D:C6:ED:FA", "9E:4D:23:CB:A8:CD"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "haos17-3"
  network_device {
    bridge       = "vmbr0"
    disconnected = false
    firewall     = false
    mac_address  = "02:AF:81:79:C4:10"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }
  node_name           = local.guests.homeassistant.node
  on_boot             = true
  pool_id             = ""
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = true
  scsi_hardware       = "virtio-scsi-pci"
  started             = true
  stop_on_destroy     = false
  tablet_device       = false
  tags                = ["community-script"]
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = local.guests.homeassistant.vmid
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    architecture = ""
    cores        = 2
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "qemu64"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    file_id           = ""
    import_from       = ""
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-102-disk-0"
    queues            = 0
    replicate         = true
    serial            = ""
    size              = 32
    ssd               = true
  }
  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = false
    type              = "4m"
  }
  memory {
    dedicated      = 4096
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "l26"
  }
  serial_device {
    device = "socket"
  }
  # The guest agent reports HAOS's internal interfaces here, and their MACs change
  lifecycle {
    ignore_changes = [mac_addresses]
  }
}
