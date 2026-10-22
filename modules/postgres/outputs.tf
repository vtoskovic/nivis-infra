output "cluster_id" {
  description = "Cluster ID."
  value       = digitalocean_database_cluster.this.id
}

output "cluster_urn" {
  description = "Cluster URN."
  value       = digitalocean_database_cluster.this.urn
}

output "private_host" {
  description = "Private (VPC) hostname."
  value       = digitalocean_database_cluster.this.private_host
}

output "database_url" {
  description = "Private connection URL for the application user (TLS required)."
  sensitive   = true
  value = format(
    "postgresql://%s:%s@%s:%d/%s?sslmode=require",
    digitalocean_database_user.app.name,
    urlencode(digitalocean_database_user.app.password),
    digitalocean_database_cluster.this.private_host,
    digitalocean_database_cluster.this.port,
    digitalocean_database_db.app.name,
  )
}
