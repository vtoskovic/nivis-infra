output "app_id" {
  description = "App ID; stored as a GitHub Environment variable for the deploy workflow."
  value       = module.app.app_id
}

output "public_url" {
  description = "Public URL of this environment."
  value       = local.public_url
}

output "default_ingress" {
  description = "Fallback ondigitalocean.app URL."
  value       = module.app.default_ingress
}

output "documents_bucket" {
  description = "Documents bucket name."
  value       = module.storage.documents_bucket
}

output "backups_bucket" {
  description = "Backups bucket name."
  value       = module.storage.backups_bucket
}

output "postgres_cluster_id" {
  description = "PostgreSQL cluster ID."
  value       = module.postgres.cluster_id
}
