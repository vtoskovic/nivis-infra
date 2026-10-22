output "app_id" {
  description = "App ID (set as the APP_ID variable of the GitHub Environment)."
  value       = module.environment.app_id
}

output "public_url" {
  description = "Public URL."
  value       = module.environment.public_url
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
