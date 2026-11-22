terraform {
  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "~> 1.99"
    }
  }
}

# The REST API over www-ssl, whose certificate the bootstrap self-signs (README: Router), hence insecure.
# Variables rather than the provider's ROS_* env vars, since it requires these even for tofu validate
provider "routeros" {
  hosturl  = var.router_url
  username = var.router_username
  password = var.router_password
  insecure = true
}
