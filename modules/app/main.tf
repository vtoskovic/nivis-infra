locals {
  image = {
    registry_type = "DOCR"
    repository    = var.image_repository
    tag           = var.image_tag
  }

  worker_command = "/app/entrypoint.worker.sh celery -A nivis.conf worker -B -l INFO -Q default --concurrency ${var.worker_concurrency} --without-gossip --without-mingle"
}

resource "digitalocean_app" "this" {
  project_id = var.project_id

  spec {
    name   = var.name_prefix
    region = var.region

    dynamic "domain" {
      for_each = var.domain == null ? [] : [var.domain]
      content {
        name = domain.value
        type = "PRIMARY"
        zone = var.dns_zone
      }
    }

    vpc {
      id = var.vpc_id
    }

    # --- App-wide environment (shared by api, worker and migrate job) ----------------------------
    dynamic "env" {
      for_each = var.env
      content {
        key   = env.key
        value = env.value
        scope = "RUN_TIME"
        type  = "GENERAL"
      }
    }

    dynamic "env" {
      # Keys are not secret; values are. Iterating keys keeps the values out of plan diffs.
      for_each = nonsensitive(toset(keys(var.secret_env)))
      content {
        key   = env.value
        value = var.secret_env[env.value]
        scope = "RUN_TIME"
        type  = "SECRET"
      }
    }

    # --- Routing: backend paths -> api, everything else -> SPA -----------------------------------
    ingress {
      dynamic "rule" {
        for_each = var.backend_path_prefixes
        content {
          component {
            name                 = "api"
            preserve_path_prefix = true
          }
          match {
            path {
              prefix = rule.value
            }
          }
        }
      }

      rule {
        component {
          name = "frontend"
        }
        match {
          path {
            prefix = "/"
          }
        }
      }
    }

    # --- Frontend: static site on App Platform's edge CDN ---------------------------------------
    static_site {
      name              = "frontend"
      dockerfile_path   = "frontend/Dockerfile"
      output_dir        = "/usr/share/nginx/html"
      catchall_document = "index.html"

      github {
        repo           = var.github_repo
        branch         = var.frontend_branch
        deploy_on_push = false
      }
    }

    # --- API: Django on Daphne ------------------------------------------------------------------
    service {
      name               = "api"
      instance_size_slug = var.api_instance_size
      instance_count     = var.api_instance_count
      http_port          = 8000

      image {
        registry_type = local.image.registry_type
        repository    = local.image.repository
        tag           = local.image.tag
      }

      health_check {
        http_path             = "/health/ready/"
        initial_delay_seconds = 20
        period_seconds        = 15
        timeout_seconds       = 5
        failure_threshold     = 3
      }

      liveness_health_check {
        http_path             = "/health/live/"
        initial_delay_seconds = 30
        period_seconds        = 30
        timeout_seconds       = 5
        failure_threshold     = 5
      }

      alert {
        rule     = "CPU_UTILIZATION"
        operator = "GREATER_THAN"
        value    = 80
        window   = "TEN_MINUTES"
      }

      alert {
        rule     = "MEM_UTILIZATION"
        operator = "GREATER_THAN"
        value    = 85
        window   = "TEN_MINUTES"
      }

      alert {
        rule     = "RESTART_COUNT"
        operator = "GREATER_THAN"
        value    = 3
        window   = "THIRTY_MINUTES"
      }
    }

    # --- Worker: Celery worker with embedded beat (single instance by design) -------------------
    worker {
      name               = "worker"
      instance_size_slug = var.worker_instance_size
      instance_count     = 1
      run_command        = local.worker_command

      image {
        registry_type = local.image.registry_type
        repository    = local.image.repository
        tag           = local.image.tag
      }

      alert {
        rule     = "RESTART_COUNT"
        operator = "GREATER_THAN"
        value    = 3
        window   = "THIRTY_MINUTES"
      }
    }

    # --- Migrations: run once per deploy, before traffic moves to the new version --------------
    job {
      name               = "migrate"
      kind               = "PRE_DEPLOY"
      instance_size_slug = var.job_instance_size
      run_command        = "python manage.py migrate --noinput"

      image {
        registry_type = local.image.registry_type
        repository    = local.image.repository
        tag           = local.image.tag
      }

      env {
        key   = "MIGRATIONS_ON_STARTUP"
        value = "true"
        scope = "RUN_TIME"
        type  = "GENERAL"
      }
    }

    # --- App-level alerts ----------------------------------------------------------------------
    dynamic "alert" {
      for_each = toset(["DEPLOYMENT_FAILED", "DOMAIN_FAILED"])
      content {
        rule = alert.value

        dynamic "destinations" {
          for_each = length(var.alert_emails) > 0 ? [1] : []
          content {
            emails = var.alert_emails
          }
        }
      }
    }
  }
}
