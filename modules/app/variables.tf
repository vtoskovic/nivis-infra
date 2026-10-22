variable "name_prefix" {
  description = "App name, e.g. \"nivis-prod\"."
  type        = string
}

variable "region" {
  description = "App Platform region slug, e.g. \"fra\"."
  type        = string
}

variable "project_id" {
  description = "DigitalOcean project the app belongs to."
  type        = string
}

variable "vpc_id" {
  description = "VPC the app joins for private access to PostgreSQL and Valkey."
  type        = string
}

variable "domain" {
  description = "Custom domain, e.g. \"portal.example.rs\". Null uses the default ondigitalocean.app URL."
  type        = string
  default     = null
}

variable "dns_zone" {
  description = "DigitalOcean-managed DNS zone for the domain (records are created automatically). Null if DNS is external."
  type        = string
  default     = null
}

variable "public_url" {
  description = "Public base URL (https://...) baked into the SPA build."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository of the app, \"owner/name\". The DigitalOcean GitHub app must have access."
  type        = string
}

variable "frontend_branch" {
  description = "Branch the static site is built from."
  type        = string
}

variable "image_repository" {
  description = "DOCR repository of the backend image."
  type        = string
}

variable "image_tag" {
  description = "Moving tag deployed to this environment (e.g. \"test\" or \"prod\"). CI re-points it and triggers a deployment."
  type        = string
}

variable "api_instance_size" {
  description = "Instance size slug for the api service."
  type        = string
}

variable "api_instance_count" {
  description = "Number of api instances."
  type        = number
  default     = 1
}

variable "worker_instance_size" {
  description = "Instance size slug for the Celery worker."
  type        = string
}

variable "worker_concurrency" {
  description = "Celery worker concurrency."
  type        = number
  default     = 2
}

variable "job_instance_size" {
  description = "Instance size slug for the migrate job."
  type        = string
  default     = "apps-s-1vcpu-0.5gb"
}

variable "backend_path_prefixes" {
  description = "URL prefixes routed to the api; everything else goes to the SPA."
  type        = list(string)
  default     = ["/api", "/admin", "/health", "/static", "/version"]
}

variable "env" {
  description = "Non-secret runtime environment variables."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Secret runtime environment variables (stored encrypted by App Platform)."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "alert_emails" {
  description = "Recipients of deployment/domain alerts."
  type        = list(string)
  default     = []
}
