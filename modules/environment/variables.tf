variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["test", "prod"], var.environment)
    error_message = "environment must be \"test\" or \"prod\"."
  }
}

variable "region" {
  description = "Datacenter for VPC, databases and documents bucket."
  type        = string
  default     = "fra1"
}

variable "app_region" {
  description = "App Platform region (must contain var.region)."
  type        = string
  default     = "fra"
}

variable "backup_region" {
  description = "Datacenter for the backups bucket (different from region)."
  type        = string
  default     = "ams3"
}

variable "vpc_ip_range" {
  description = "VPC CIDR; unique per environment."
  type        = string
}

variable "domain" {
  description = "Public hostname of this environment, e.g. \"portal.example.rs\"; null until it exists (the app is then served on its ondigitalocean.app URL)."
  type        = string
  default     = null
}

variable "dns_zone" {
  description = "DigitalOcean-managed DNS zone containing the domain, or null if DNS is hosted elsewhere."
  type        = string
  default     = null
}

variable "github_repo" {
  description = "Application repository, \"owner/name\"."
  type        = string
}

variable "frontend_branch" {
  description = "Branch the static site is built from (test: main, prod: release)."
  type        = string
}

variable "image_repository" {
  description = "DOCR repository of the backend image."
  type        = string
  default     = "backend"
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
  description = "Retention settings for Spaces buckets."
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

variable "num_proxies" {
  description = "Trusted X-Forwarded-For hops in front of Django (App Platform edge + router)."
  type        = number

  validation {
    condition     = var.num_proxies >= 0
    error_message = "num_proxies must not be negative."
  }
}

variable "lab" {
  description = "Laboratory identity shown in the app and reports."
  type = object({
    name       = string
    short_name = string
    address    = string
  })
}

variable "email_backend" {
  description = "Django email backend class."
  type        = string
  default     = "anymail.backends.resend.EmailBackend"
}

variable "hsts_seconds" {
  description = "Strict-Transport-Security max-age."
  type        = number
  default     = 31536000
}

variable "alert_emails" {
  description = "Recipients of deployment, domain and uptime alerts."
  type        = list(string)
}

variable "admin_ip_addresses" {
  description = "Temporary operator IPs allowed into PostgreSQL. Keep empty."
  type        = list(string)
  default     = []
}

variable "extra_env" {
  description = "Additional non-secret env vars ."
  type        = map(string)
  default     = {}
}

variable "extra_secret_env" {
  description = "Additional secret env vars (e.g. the email provider API key). Pass via TF_VAR_extra_secret_env from CI secrets."
  type        = map(string)
  sensitive   = true
  default     = {}
}
