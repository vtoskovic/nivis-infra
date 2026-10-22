output "app_id" {
  description = "App ID (used by CI to trigger deployments)."
  value       = digitalocean_app.this.id
}

output "app_urn" {
  description = "App URN."
  value       = digitalocean_app.this.urn
}

output "default_ingress" {
  description = "Default ondigitalocean.app URL."
  value       = digitalocean_app.this.default_ingress
}

output "live_url" {
  description = "Live URL (custom domain once verified)."
  value       = digitalocean_app.this.live_url
}
