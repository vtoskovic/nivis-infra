output "registry_endpoint" {
  description = "Registry endpoint used by CI to push images."
  value       = digitalocean_container_registry.this.endpoint
}

output "dns_nameservers_hint" {
  description = "Point the registrar at these nameservers when dns_zone is set."
  value       = var.dns_zone == null ? null : ["ns1.digitalocean.com", "ns2.digitalocean.com", "ns3.digitalocean.com"]
}
