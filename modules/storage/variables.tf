variable "name_prefix" {
  description = "Prefix for bucket names (globally unique across Spaces), e.g. \"nivis-prod\"."
  type        = string
}

variable "region" {
  description = "Region of the documents bucket, e.g. \"fra1\"."
  type        = string
}

variable "backup_region" {
  description = "Region of the backups bucket; must differ from region, e.g. \"ams3\"."
  type        = string

  validation {
    condition     = var.backup_region != var.region
    error_message = "backup_region must differ from region so backups survive a regional outage."
  }
}

variable "allowed_origins" {
  description = "Origins allowed to fetch documents directly from the bucket (CORS)."
  type        = list(string)
}

variable "noncurrent_version_retention_days" {
  description = "How long overwritten/deleted document versions are kept."
  type        = number
  default     = 90
}

variable "document_expiration_days" {
  description = "Expire current documents after N days. Null (default) keeps them; set only on test."
  type        = number
  default     = null
}

variable "backup_retention_days" {
  description = "How long database dumps are kept in the backups bucket."
  type        = number
  default     = 400
}
