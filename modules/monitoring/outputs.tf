output "uptime_check_id" {
  description = "Uptime check ID."
  value       = digitalocean_uptime_check.this.id
}
