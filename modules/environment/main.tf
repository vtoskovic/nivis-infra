# One complete nivis environment. test and prod call this module with identical services;
# only sizes and a few retention settings differ (see stacks/<env>/terraform.tfvars).

locals {
  name_prefix = "nivis-${var.environment}"
  tags        = ["nivis", "env-${var.environment}", "managed-by-terraform"]

  # Non-secret env sent to the app. URL envs use App Platform bindables so no hostname is hard-coded.
  runtime_env = {
    DEBUG                  = "False"
    TIME_ZONE              = "Europe/Belgrade"
    ALLOWED_HOSTS          = "$${APP_DOMAIN}"
    FRONTEND_URL           = "$${APP_URL}"
    BACKEND_PUBLIC_URL     = "$${APP_URL}"
    CSRF_TRUSTED_ORIGINS   = "$${APP_URL}"
    CORS_ALLOWED_ORIGINS   = "$${APP_URL}"
    DEFAULT_FROM_EMAIL     = var.default_from_email
    NUM_PROXIES            = tostring(var.num_proxies)
    SECURE_HSTS_SECONDS    = tostring(var.hsts_seconds)
    S3_BUCKET              = module.storage.documents_bucket
    S3_ENDPOINT_URL        = "https://${var.region}.digitaloceanspaces.com"
    S3_PUBLIC_ENDPOINT_URL = "https://${var.region}.digitaloceanspaces.com"
    S3_ADDRESSING_STYLE    = "virtual"
    AWS_S3_REGION_NAME     = var.region
    EMAIL_BACKEND          = var.email_backend
    LAB_NAME               = var.lab.name
    LAB_SHORT_NAME         = var.lab.short_name
    LAB_ADDRESS            = var.lab.address
    SENTRY_ENVIRONMENT     = var.environment
    LOG_LEVEL              = "INFO"
  }

  secret_env = merge(
    {
      SECRET_KEY            = random_password.django_secret_key.result
      JWT_SIGNING_KEY       = random_password.jwt_signing_key.result
      AUDIT_HMAC_KEY        = random_password.audit_hmac_key.result
      DATABASE_URL          = module.postgres.database_url
      REDIS_URL             = module.valkey.cache_url
      CELERY_BROKER_URL     = module.valkey.broker_url
      CELERY_RESULT_BACKEND = module.valkey.result_backend_url
      AWS_ACCESS_KEY_ID     = module.storage.app_access_key
      AWS_SECRET_ACCESS_KEY = module.storage.app_secret_key
    },
    var.extra_secret_env,
  )
}

resource "digitalocean_project" "this" {
  name        = local.name_prefix
  description = "nivis portal – ${var.environment} environment"
  purpose     = "Web Application"
  environment = var.environment == "prod" ? "Production" : "Development"
}

module "network" {
  source = "../network"

  name_prefix = local.name_prefix
  region      = var.region
  ip_range    = var.vpc_ip_range
}

module "postgres" {
  source = "../postgres"

  name_prefix        = local.name_prefix
  region             = var.region
  vpc_id             = module.network.vpc_id
  vpc_ip_range       = module.network.ip_range
  project_id         = digitalocean_project.this.id
  trusted_app_id     = module.app.app_id
  size               = var.postgres.size
  node_count         = var.postgres.node_count
  pg_version         = var.postgres.version
  admin_ip_addresses = var.admin_ip_addresses
  tags               = local.tags
}

module "valkey" {
  source = "../valkey"

  name_prefix    = local.name_prefix
  region         = var.region
  vpc_id         = module.network.vpc_id
  vpc_ip_range   = module.network.ip_range
  project_id     = digitalocean_project.this.id
  trusted_app_id = module.app.app_id
  size           = var.valkey.size
  node_count     = var.valkey.node_count
  tags           = local.tags
}

module "storage" {
  source = "../storage"

  name_prefix                       = local.name_prefix
  region                            = var.region
  backup_region                     = var.backup_region
  document_expiration_days          = var.storage.document_expiration_days
  noncurrent_version_retention_days = var.storage.noncurrent_version_retention_days
  backup_retention_days             = var.storage.backup_retention_days
}

resource "digitalocean_project_resources" "buckets" {
  project   = digitalocean_project.this.id
  resources = module.storage.bucket_urns
}

# --- Application secrets: generated once, stored only in (encrypted, private) state and App Platform.
resource "random_password" "django_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "jwt_signing_key" {
  length  = 64
  special = false
}

resource "random_password" "audit_hmac_key" {
  length  = 64
  special = false
}

module "app" {
  source = "../app"

  name_prefix          = local.name_prefix
  region               = var.app_region
  project_id           = digitalocean_project.this.id
  vpc_id               = module.network.vpc_id
  domain               = var.domain
  dns_zone             = var.dns_zone
  github_repo          = var.github_repo
  frontend_branch      = var.frontend_branch
  image_repository     = var.image_repository
  image_tag            = var.environment
  api_instance_size    = var.app.api_instance_size
  api_instance_count   = var.app.api_instance_count
  worker_instance_size = var.app.worker_instance_size
  worker_concurrency   = var.app.worker_concurrency
  alert_emails         = var.alert_emails

  env        = merge(local.runtime_env, var.extra_env)
  secret_env = local.secret_env
}

module "monitoring" {
  source = "../monitoring"

  name_prefix  = local.name_prefix
  target_url   = "${trimsuffix(module.app.live_url, "/")}/health/live/"
  alert_emails = var.alert_emails
}
