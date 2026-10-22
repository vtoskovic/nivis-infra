resource "digitalocean_vpc" "this" {
  name        = "${var.name_prefix}-vpc"
  region      = var.region
  ip_range    = var.ip_range
  description = "Private network for ${var.name_prefix} (App Platform, PostgreSQL, Valkey)"
}
