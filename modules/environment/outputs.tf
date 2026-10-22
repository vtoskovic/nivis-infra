output "app_id" {
  description = "App ID; stored as a GitHub Environment variable for the deploy workflow."
  value       = module.app.app_id
}

output "live_url" {
  description = "Live URL of this environment (custom domain once verified, else the default ingress)."
  value       = module.app.live_url
}

output "runtime_env" {
  description = "Non-secret env vars as sent to the app."
  value       = merge(local.runtime_env, var.extra_env)
}

output "secret_env_keys" {
  description = "Names (never values) of the secret env vars sent to the app."
  value       = nonsensitive(sort(keys(local.secret_env)))
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
