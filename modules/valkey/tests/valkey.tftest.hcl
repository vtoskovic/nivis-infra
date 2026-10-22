mock_provider "digitalocean" {}

variables {
  name_prefix    = "nivis-test"
  region         = "fra1"
  vpc_id         = "v"
  vpc_ip_range   = "10.110.0.0/20"
  project_id     = "p"
  trusted_app_id = "a"
  size           = "db-s-1vcpu-1gb"
}

run "noeviction_pinned" {
  command = plan
  assert {
    condition     = digitalocean_database_valkey_config.this.valkey_maxmemory_policy == "noeviction"
    error_message = "Valkey backs the Celery broker; it must never evict queued tasks."
  }
}
