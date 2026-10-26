variable "name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "node_name" {
  type = string
}

variable "template_file_id" {
  type = string
}

variable "os_type" {
  type    = string
  default = "debian"
}

variable "cores" {
  type    = number
  default = 1
}

variable "memory" {
  type    = number
  default = 512
}

variable "swap" {
  type    = number
  default = 512
}

variable "disk_size" {
  type    = number
  default = 4
}

variable "datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "ipv4_address" {
  type        = string
  default     = "dhcp"
  description = "\"dhcp\" or a CIDR like 192.168.0.20/24"
}

variable "ipv4_gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "ipv6_address" {
  type        = string
  default     = null
  description = "null to leave IPv6 unconfigured, \"dhcp\", \"auto\" or a CIDR"
}

variable "dns_servers" {
  type        = list(string)
  default     = []
  description = "Empty to inherit the Proxmox host's resolv.conf"
}

variable "ssh_public_keys" {
  type    = list(string)
  default = []
}

variable "started" {
  type    = bool
  default = true
}

variable "start_on_boot" {
  type    = bool
  default = true
}

variable "unprivileged" {
  type    = bool
  default = true
}

variable "nesting" {
  type    = bool
  default = true
}

variable "tags" {
  type    = list(string)
  default = []
}
variable "device_passthrough" {
  type    = list(string)
  default = []
}

variable "interface_name" {
  type    = string
  default = "eth0"
}

variable "firewall" {
  type    = bool
  default = false
}

variable "mount_points" {
  type = list(object({
    volume = string
    path   = string
    backup = optional(bool, false)
    size   = optional(string)
  }))
  default     = []
  description = "Bind mounts or volumes, e.g. { volume = \"/srv/data\", path = \"/mnt/data\" }, or { volume = \"local-lvm\", size = \"100G\", ... } for a new volume"
}
