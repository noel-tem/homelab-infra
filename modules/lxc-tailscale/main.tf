module "lxc" {
  source = "../lxc"

  name               = var.name
  vm_id              = var.vm_id
  node_name          = var.node_name
  template_file_id   = var.template_file_id
  os_type            = var.os_type
  cores              = var.cores
  memory             = var.memory
  swap               = var.swap
  disk_size          = var.disk_size
  datastore_id       = var.datastore_id
  ipv4_address       = var.ipv4_address
  ipv4_gateway       = var.ipv4_gateway
  ssh_public_keys    = var.ssh_public_keys
  started            = var.started
  start_on_boot      = var.start_on_boot
  unprivileged       = var.unprivileged
  nesting            = var.nesting
  tags               = concat(["tailscale"], var.tags)
  device_passthrough = var.tun_passthrough ? ["/dev/net/tun"] : []
}

locals {
  host             = var.ipv4_address == "dhcp" ? module.lxc.ipv4 : split("/", var.ipv4_address)[0]
  tailscaled_flags = var.tun_passthrough ? "" : "--tun=userspace-networking"
}

# Anchors the auth key to the container, so a rebuilt container gets a fresh key
resource "terraform_data" "container" {
  input = module.lxc.id
}

resource "tailscale_tailnet_key" "this" {
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags          = var.tailscale_tags
  description   = "tofu-${var.name}"

  lifecycle {
    replace_triggered_by = [terraform_data.container]
  }
}

resource "terraform_data" "tailscale" {
  triggers_replace = [module.lxc.id, tailscale_tailnet_key.this.id]
  input            = { host = local.host }

  connection {
    type  = "ssh"
    host  = self.input.host
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates",
      "curl -fsSL https://tailscale.com/install.sh | sh",
      "sed -i 's|^FLAGS=.*|FLAGS=\"${local.tailscaled_flags}\"|' /etc/default/tailscaled",
      "systemctl restart tailscaled",
      "tailscale up --auth-key=${tailscale_tailnet_key.this.key} --hostname=${var.name}",
    ]
  }

  # Removes the node from the tailnet so a rebuild doesn't leave a stale "name-1" device behind
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline     = ["tailscale logout || true"]
  }
}

data "tailscale_device" "this" {
  hostname   = var.name
  wait_for   = "60s"
  depends_on = [terraform_data.tailscale]
}
