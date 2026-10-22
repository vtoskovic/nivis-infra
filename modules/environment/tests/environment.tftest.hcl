mock_provider "digitalocean" {}
mock_provider "random" {}

variables {
  environment        = "test"
  vpc_ip_range       = "10.20.0.0/24"
  github_repo        = "nivns/nivis"
  frontend_branch    = "test"
  default_from_email = "noreply@test.invalid"
  alert_emails       = ["ops@test.invalid"]
  num_proxies        = 1

  app = {
    api_instance_size    = "apps-s-1vcpu-0.5gb"
    api_instance_count   = 1
    worker_instance_size = "apps-s-1vcpu-1gb"
    worker_concurrency   = 2
  }
  postgres = {
    size       = "db-s-1vcpu-1gb"
    node_count = 1
  }
  valkey = {
    size       = "db-s-1vcpu-1gb"
    node_count = 1
  }
  storage = {
    noncurrent_version_retention_days = 30
    backup_retention_days             = 30
  }
  lab = {
    name       = "Test laboratorija"
    short_name = "TL"
    address    = "Ulica 1, Beograd"
  }
}

run "urls_use_bindables" {
  command = plan
  assert {
    condition = alltrue([
      output.runtime_env["FRONTEND_URL"] == "$${APP_URL}",
      output.runtime_env["BACKEND_PUBLIC_URL"] == "$${APP_URL}",
      output.runtime_env["CSRF_TRUSTED_ORIGINS"] == "$${APP_URL}",
      output.runtime_env["CORS_ALLOWED_ORIGINS"] == "$${APP_URL}",
      output.runtime_env["ALLOWED_HOSTS"] == "$${APP_DOMAIN}",
    ])
    error_message = "Public-URL envs must use App Platform bindables."
  }
}

run "spaces_settings" {
  command = plan
  assert {
    condition = alltrue([
      output.runtime_env["S3_ENDPOINT_URL"] == "https://fra1.digitaloceanspaces.com",
      output.runtime_env["S3_PUBLIC_ENDPOINT_URL"] == "https://fra1.digitaloceanspaces.com",
      output.runtime_env["S3_ADDRESSING_STYLE"] == "virtual",
      output.runtime_env["AWS_S3_REGION_NAME"] == "fra1",
    ])
    error_message = "Spaces settings are wrong."
  }
}

run "email_and_lab" {
  command = plan
  assert {
    condition = alltrue([
      output.runtime_env["EMAIL_BACKEND"] == "anymail.backends.resend.EmailBackend",
      output.runtime_env["LAB_NAME"] == "Test laboratorija",
      output.runtime_env["LAB_SHORT_NAME"] == "TL",
      output.runtime_env["LAB_ADDRESS"] == "Ulica 1, Beograd",
      output.runtime_env["NUM_PROXIES"] == "1",
    ])
    error_message = "Email backend, lab identity and NUM_PROXIES must be wired."
  }
}

run "no_literal_hosts" {
  command = plan
  assert {
    condition = alltrue([
      for k in ["FRONTEND_URL", "BACKEND_PUBLIC_URL", "CSRF_TRUSTED_ORIGINS", "CORS_ALLOWED_ORIGINS", "ALLOWED_HOSTS"] :
      startswith(output.runtime_env[k], "$${APP_")
    ])
    error_message = "No literal hostnames in the URL envs."
  }
}

run "secret_keys_exact" {
  command = plan
  assert {
    condition = toset(output.secret_env_keys) == toset([
      "SECRET_KEY", "JWT_SIGNING_KEY", "AUDIT_HMAC_KEY", "DATABASE_URL", "REDIS_URL",
      "CELERY_BROKER_URL", "CELERY_RESULT_BACKEND", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
    ])
    error_message = "Secret env keys differ from the spec."
  }
}

run "num_proxies_not_negative" {
  command = plan
  variables {
    num_proxies = -1
  }
  expect_failures = [var.num_proxies]
}
