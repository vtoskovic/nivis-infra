# Account-wide resources shared by test and prod.

# One registry per account. Starter (free) = 1 repository, enough for the single backend image
# (the frontend is built by App Platform as a static site and never stored here).
resource "digitalocean_container_registry" "this" {
  name                   = var.registry_name
  subscription_tier_slug = var.registry_tier
  region                 = var.region
}

# Optional: host the DNS zone on DigitalOcean so App Platform creates records automatically.
# Leave dns_zone = null when DNS stays with the current registrar.
resource "digitalocean_domain" "this" {
  count = var.dns_zone == null ? 0 : 1
  name  = var.dns_zone
}
