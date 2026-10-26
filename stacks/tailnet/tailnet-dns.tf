# Tailnet clients send *.home.arpa lookups to Pi-hole over the subnet route
resource "tailscale_dns_split_nameservers" "home_arpa" {
  domain      = local.shared.dns_domain
  nameservers = [local.pihole_ip]
}
