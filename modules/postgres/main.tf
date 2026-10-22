resource "digitalocean_database_cluster" "this" {
  name                 = "${var.name_prefix}-pg"
  engine               = "pg"
  version              = var.pg_version
  size                 = var.size
  node_count           = var.node_count
  region               = var.region
  private_network_uuid = var.vpc_id
  project_id           = var.project_id
  tags                 = var.tags

  maintenance_window {
    day  = var.maintenance_day
    hour = var.maintenance_hour
  }

  lifecycle {
    # Losing the cluster loses every request and report. Remove deliberately, never by accident.
    prevent_destroy = true
  }
}

resource "digitalocean_database_db" "app" {
  cluster_id = digitalocean_database_cluster.this.id
  name       = var.db_name
}

# Dedicated least-privilege application user; the doadmin credentials are never handed to the app.
resource "digitalocean_database_user" "app" {
  cluster_id = digitalocean_database_cluster.this.id
  name       = var.db_user
}

# Trusted sources: only the App Platform app and the private VPC range may connect.
# Operator IPs are opt-in (empty by default) and should be removed after one-off maintenance.
resource "digitalocean_database_firewall" "this" {
  cluster_id = digitalocean_database_cluster.this.id

  rule {
    type  = "app"
    value = var.trusted_app_id
  }

  rule {
    type  = "ip_addr"
    value = var.vpc_ip_range
  }

  dynamic "rule" {
    for_each = toset(var.admin_ip_addresses)
    content {
      type  = "ip_addr"
      value = rule.value
    }
  }
}
