variable "name_prefix" {
  description = "Prefix for resource names, e.g. \"nivis-prod\"."
  type        = string
}

variable "region" {
  description = "DigitalOcean datacenter slug, e.g. \"fra1\"."
  type        = string
}

variable "ip_range" {
  description = "Private CIDR for the VPC. Must not overlap any other VPC in the account."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ip_range))
    error_message = "ip_range must be a valid IPv4 CIDR block."
  }
}
