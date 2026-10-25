# Shared by every guest in this stack
locals {
    node = "live-laugh-homelab"
    proxmox_host = "192.168.0.50"
    debian_template = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
    ssh_keys = [trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))]
}
