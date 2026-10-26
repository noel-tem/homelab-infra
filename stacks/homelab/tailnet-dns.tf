# Tailnet clients send *.home.arpa lookups to Pi-hole over the subnet route
resource "tailscale_dns_split_nameservers" "home_arpa" {
    domain      = "home.arpa"
    nameservers = ["192.168.0.10"]
}
