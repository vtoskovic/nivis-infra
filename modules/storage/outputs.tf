output "documents_bucket" {
  description = "Documents bucket name."
  value       = digitalocean_spaces_bucket.documents.name
}

output "documents_endpoint" {
  description = "S3 endpoint URL for the documents bucket region."
  value       = "https://${var.region}.digitaloceanspaces.com"
}

output "backups_bucket" {
  description = "Backups bucket name."
  value       = digitalocean_spaces_bucket.backups.name
}

output "bucket_urns" {
  description = "URNs of all buckets (for project assignment)."
  value       = [digitalocean_spaces_bucket.documents.urn, digitalocean_spaces_bucket.backups.urn]
}

output "app_access_key" {
  description = "Spaces access key ID for the app (documents bucket only)."
  sensitive   = true
  value       = digitalocean_spaces_key.app.access_key
}

output "app_secret_key" {
  description = "Spaces secret key for the app (documents bucket only)."
  sensitive   = true
  value       = digitalocean_spaces_key.app.secret_key
}

output "backup_access_key" {
  description = "Spaces access key ID for the backup job (backups bucket only)."
  sensitive   = true
  value       = digitalocean_spaces_key.backup.access_key
}

output "backup_secret_key" {
  description = "Spaces secret key for the backup job (backups bucket only)."
  sensitive   = true
  value       = digitalocean_spaces_key.backup.secret_key
}
