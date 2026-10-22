variable "name_prefix" {
  description = "Prefix for resource names, e.g. \"nivis-prod\"."
  type        = string
}

variable "region" {
  description = "DigitalOcean datacenter slug, e.g. \"fra1\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC UUID the cluster is attached to."
  type        = string
}

variable "vpc_ip_range" {
  description = "VPC CIDR allowed as a trusted source."
  type        = string
}

variable "project_id" {
  description = "DigitalOcean project the cluster belongs to."
  type        = string
}

variable "trusted_app_id" {
  description = "App Platform app ID allowed to connect."
  type        = string
}

variable "pg_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "17"
}

variable "size" {
  description = "Node size slug, e.g. \"db-s-1vcpu-1gb\"."
  type        = string
}

variable "node_count" {
  description = "1 = primary only; 2+ adds standby nodes with automatic failover."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "node_count must be between 1 and 3."
  }
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "nivis"
}

variable "db_user" {
  description = "Application database user."
  type        = string
  default     = "nivis"
}

variable "maintenance_day" {
  description = "Weekly maintenance day."
  type        = string
  default     = "sunday"
}

variable "maintenance_hour" {
  description = "Maintenance start (UTC), HH:MM:SS."
  type        = string
  default     = "02:00:00"
}

variable "admin_ip_addresses" {
  description = "Optional operator IPs/CIDRs allowed to connect (one-off maintenance only). Keep empty."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the cluster."
  type        = list(string)
  default     = []
}
