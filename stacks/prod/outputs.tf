output "app_id" {
  description = "App ID (set as the repo variable PROD_APP_ID in the nivis repo)."
  value       = module.environment.app_id
}

output "live_url" {
  description = "Live URL."
  value       = module.environment.live_url
}

output "default_ingress" {
  description = "Fallback ondigitalocean.app URL."
  value       = module.environment.default_ingress
}

output "documents_bucket" {
  description = "Documents bucket."
  value       = module.environment.documents_bucket
}

output "backups_bucket" {
  description = "Backups bucket."
  value       = module.environment.backups_bucket
}

output "runtime_env" {
  description = "Non-secret env vars as sent to the app. Review env changes here: plans show every app env value as (sensitive value)."
  value       = module.environment.runtime_env
}

output "secret_env_keys" {
  description = "Names (never values) of the secret env vars sent to the app."
  value       = module.environment.secret_env_keys
}
