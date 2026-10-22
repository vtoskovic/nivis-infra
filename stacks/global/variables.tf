variable "region" {
  description = "Registry region."
  type        = string
  default     = "fra1"
}

variable "registry_name" {
  description = "Container registry name (globally unique)."
  type        = string
}

variable "registry_tier" {
  description = "Registry tier: starter (free, 1 repo), basic, professional."
  type        = string
  default     = "basic"

  validation {
    condition     = contains(["starter", "basic", "professional"], var.registry_tier)
    error_message = "registry_tier must be starter, basic or professional."
  }
}

variable "dns_zone" {
  description = "Apex zone to host on DigitalOcean DNS (e.g. \"example.rs\"), or null."
  type        = string
  default     = null
}
