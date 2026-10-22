resource "digitalocean_database_cluster" "this" {
  name                 = "${var.name_prefix}-valkey"
  engine               = "valkey"
  version              = var.valkey_version
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
}

# Celery broker: never evict queued tasks.
resource "digitalocean_database_valkey_config" "this" {
  cluster_id              = digitalocean_database_cluster.this.id
  valkey_maxmemory_policy = "noeviction"
}

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
}

locals {
  # rediss:// (TLS) over the private network. Celery requires ssl_cert_reqs on rediss URLs.
  base_url = format(
    "rediss://%s:%s@%s:%d",
    digitalocean_database_cluster.this.user,
    urlencode(digitalocean_database_cluster.this.password),
    digitalocean_database_cluster.this.private_host,
    digitalocean_database_cluster.this.port,
  )
}
