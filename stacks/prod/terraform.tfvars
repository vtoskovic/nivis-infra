# prod – same services as test, sized for low traffic. Non-secret values only.
# Scale up by editing sizes here; every change goes through the same reviewed pipeline.
environment  = "prod"
vpc_ip_range = "10.120.0.0/20"

domain          = "portal.example.rs" # TODO: real hostname
dns_zone        = null                # set to the apex zone if DNS is hosted on DigitalOcean
github_repo     = "CHANGE-ME/nivis"   # TODO: owner/repo
frontend_branch = "release"

app = {
  api_instance_size    = "apps-s-1vcpu-1gb-fixed" # $10; move to apps-s-1vcpu-1gb for >1 instance
  api_instance_count   = 1
  worker_instance_size = "apps-s-1vcpu-0.5gb" # $5, worker + beat
  worker_concurrency   = 2
}

postgres = {
  size       = "db-s-1vcpu-1gb" # $15; node_count = 2 adds a standby with automatic failover (+$15)
  node_count = 1
}

valkey = {
  size       = "db-s-1vcpu-1gb" # $15
  node_count = 1
}

storage = {
  noncurrent_version_retention_days = 365
  backup_retention_days             = 400
}

default_from_email = "no-reply@example.rs" # TODO
hsts_seconds       = 31536000
alert_emails       = ["ops@example.rs"] # TODO
