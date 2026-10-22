module "environment" {
  source = "../../modules/environment"

  environment        = var.environment
  vpc_ip_range       = var.vpc_ip_range
  domain             = var.domain
  dns_zone           = var.dns_zone
  github_repo        = var.github_repo
  frontend_branch    = var.frontend_branch
  app                = var.app
  postgres           = var.postgres
  valkey             = var.valkey
  storage            = var.storage
  default_from_email = var.default_from_email
  num_proxies        = var.num_proxies
  lab                = var.lab
  email_backend      = var.email_backend
  hsts_seconds       = var.hsts_seconds
  alert_emails       = var.alert_emails
  admin_ip_addresses = var.admin_ip_addresses
  extra_env          = var.extra_env
  extra_secret_env   = var.extra_secret_env
}
