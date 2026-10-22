variable "name_prefix" {
  description = "Prefix for resource names, e.g. \"nivis-prod\"."
  type        = string
}

variable "target_url" {
  description = "HTTPS URL probed by the uptime check (liveness endpoint)."
  type        = string

  validation {
    condition     = startswith(var.target_url, "https://")
    error_message = "target_url must use https://."
  }
}

variable "regions" {
  description = "Probe regions."
  type        = list(string)
  default     = ["eu_west"]
}

variable "latency_threshold_ms" {
  description = "Alert when response time exceeds this many milliseconds."
  type        = number
  default     = 2000
}

variable "alert_emails" {
  description = "Recipients of uptime alerts."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "At least one alert recipient is required."
  }
}
