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

variable "valkey_version" {
  description = "Valkey major version."
  type        = string
  default     = "8"
}

variable "size" {
  description = "Node size slug, e.g. \"db-s-1vcpu-1gb\"."
  type        = string
}

variable "node_count" {
  description = "1 = single node; 2+ adds standby nodes."
  type        = number
  default     = 1
}

variable "maintenance_day" {
  description = "Weekly maintenance day."
  type        = string
  default     = "sunday"
}

variable "maintenance_hour" {
  description = "Maintenance start (UTC), HH:MM:SS."
  type        = string
  default     = "03:00:00"
}

variable "tags" {
  description = "Tags applied to the cluster."
  type        = list(string)
  default     = []
}
