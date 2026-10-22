# Pass-through inputs; descriptions and validation live in modules/environment.

variable "environment" {
  description = "Environment name (test | prod)."
  type        = string
}

variable "vpc_ip_range" {
  description = "VPC CIDR, unique per environment."
  type        = string
}

variable "domain" {
  description = "Public hostname of this environment."
  type        = string
}

variable "dns_zone" {
  description = "DigitalOcean-managed DNS zone, or null."
  type        = string
  default     = null
}

variable "github_repo" {
  description = "Application repository, \"owner/name\"."
  type        = string
}

variable "frontend_branch" {
  description = "Branch the static site is built from."
  type        = string
}

variable "app" {
  description = "App Platform sizing."
  type = object({
    api_instance_size    = string
    api_instance_count   = number
    worker_instance_size = string
    worker_concurrency   = number
  })
}

variable "postgres" {
  description = "Managed PostgreSQL sizing."
  type = object({
    size       = string
    node_count = number
    version    = optional(string, "17")
  })
}

variable "valkey" {
  description = "Managed Valkey sizing."
  type = object({
    size       = string
    node_count = number
  })
}

variable "storage" {
  description = "Spaces retention settings."
  type = object({
    document_expiration_days          = optional(number)
    noncurrent_version_retention_days = number
    backup_retention_days             = number
  })
}

variable "default_from_email" {
  description = "Sender address for outgoing email."
  type        = string
}

variable "hsts_seconds" {
  description = "Strict-Transport-Security max-age."
  type        = number
}

variable "alert_emails" {
  description = "Alert recipients."
  type        = list(string)
}

variable "admin_ip_addresses" {
  description = "Temporary operator IPs allowed into PostgreSQL. Keep empty."
  type        = list(string)
  default     = []
}

variable "extra_env" {
  description = "Additional non-secret env vars."
  type        = map(string)
  default     = {}
}

variable "extra_secret_env" {
  description = "Additional secret env vars, supplied only via TF_VAR_extra_secret_env in CI."
  type        = map(string)
  sensitive   = true
  default     = {}
}
