output "cluster_id" {
  description = "Cluster ID."
  value       = digitalocean_database_cluster.this.id
}

output "cluster_urn" {
  description = "Cluster URN."
  value       = digitalocean_database_cluster.this.urn
}

output "cache_url" {
  description = "Django cache URL (logical DB 0)."
  sensitive   = true
  value       = "${local.base_url}/0"
}

output "broker_url" {
  description = "Celery broker URL (logical DB 1)."
  sensitive   = true
  value       = "${local.base_url}/1?ssl_cert_reqs=required"
}

output "result_backend_url" {
  description = "Celery result backend URL (logical DB 2)."
  sensitive   = true
  value       = "${local.base_url}/2?ssl_cert_reqs=required"
}
