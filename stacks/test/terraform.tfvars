# test – same services as prod, smallest sizes. Non-secret values only.
environment  = "test"
vpc_ip_range = "10.110.0.0/20"
num_proxies  = 1 # verify on test (Part C)

lab = { name = "TODO", short_name = "NIVNS", address = "TODO" } # TODO: NIVNS

domain          = null              # TODO: NIVNS hostname, then set it here
dns_zone        = null              # set to the apex zone if DNS is hosted on DigitalOcean
github_repo     = "CHANGE-ME/nivis" # TODO: owner/repo
frontend_branch = "test"

app = {
  api_instance_size    = "apps-s-1vcpu-0.5gb" # $5
  api_instance_count   = 1
  worker_instance_size = "apps-s-1vcpu-1gb" # $10, worker + beat
  worker_concurrency   = 2
}

postgres = {
  size       = "db-s-1vcpu-1gb" # $15, single node
  node_count = 1
}

valkey = {
  size       = "db-s-1vcpu-1gb" # $15
  node_count = 1
}

storage = {
  document_expiration_days          = 90
  noncurrent_version_retention_days = 30
  backup_retention_days             = 30
}

default_from_email = "no-reply@example.rs" # TODO
hsts_seconds       = 3600
alert_emails       = ["ops@example.rs"] # TODO
