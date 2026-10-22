# One complete nivis environment. test and prod call this module with identical services;
# only sizes and a few retention settings differ (see stacks/<env>/terraform.tfvars).

locals {
  name_prefix = "nivis-${var.environment}"
  public_url  = "https://${var.domain}"
  tags        = ["nivis", "env-${var.environment}", "managed-by-terraform"]
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
  allowed_origins                   = [local.public_url]
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
  public_url           = local.public_url
  github_repo          = var.github_repo
  frontend_branch      = var.frontend_branch
  image_repository     = var.image_repository
  image_tag            = var.environment
  api_instance_size    = var.app.api_instance_size
  api_instance_count   = var.app.api_instance_count
  worker_instance_size = var.app.worker_instance_size
  worker_concurrency   = var.app.worker_concurrency
  alert_emails         = var.alert_emails

  env = merge(
    {
      DEBUG                = "False"
      TIME_ZONE            = "Europe/Belgrade"
      ALLOWED_HOSTS        = var.domain
      FRONTEND_URL         = local.public_url
      BACKEND_PUBLIC_URL   = local.public_url
      CSRF_TRUSTED_ORIGINS = local.public_url
      CORS_ALLOWED_ORIGINS = local.public_url
      DEFAULT_FROM_EMAIL   = var.default_from_email
      NUM_PROXIES          = tostring(var.num_proxies)
      SECURE_SSL_REDIRECT  = "True"
      SECURE_HSTS_SECONDS  = tostring(var.hsts_seconds)
      S3_BUCKET            = module.storage.documents_bucket
      S3_ENDPOINT_URL      = module.storage.documents_endpoint
      AWS_S3_REGION_NAME   = var.region
      SENTRY_ENVIRONMENT   = var.environment
      LOG_LEVEL            = "INFO"
    },
    var.extra_env,
  )

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

module "monitoring" {
  source = "../monitoring"

  name_prefix  = local.name_prefix
  target_url   = "${local.public_url}/health/live/"
  alert_emails = var.alert_emails
}
