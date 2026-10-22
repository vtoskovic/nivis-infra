resource "digitalocean_uptime_check" "this" {
  name    = "${var.name_prefix}-live"
  target  = var.target_url
  type    = "https"
  regions = var.regions
  enabled = true
}

resource "digitalocean_uptime_alert" "down" {
  name       = "${var.name_prefix}-down"
  check_id   = digitalocean_uptime_check.this.id
  type       = "down"
  period     = "2m"
  comparison = "less_than"
  threshold  = 1

  notifications {
    email = var.alert_emails
  }
}

resource "digitalocean_uptime_alert" "latency" {
  name       = "${var.name_prefix}-latency"
  check_id   = digitalocean_uptime_check.this.id
  type       = "latency"
  period     = "5m"
  comparison = "greater_than"
  threshold  = var.latency_threshold_ms

  notifications {
    email = var.alert_emails
  }
}

resource "digitalocean_uptime_alert" "ssl_expiry" {
  name       = "${var.name_prefix}-ssl-expiry"
  check_id   = digitalocean_uptime_check.this.id
  type       = "ssl_expiry"
  period     = "5m"
  comparison = "less_than"
  threshold  = 14

  notifications {
    email = var.alert_emails
  }
}
