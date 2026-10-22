mock_provider "digitalocean" {}

variables {
  name_prefix          = "nivis-test"
  region               = "fra"
  project_id           = "p"
  vpc_id               = "v"
  github_repo          = "nivns/nivis"
  frontend_branch      = "test"
  image_repository     = "backend"
  image_tag            = "test"
  api_instance_size    = "apps-s-1vcpu-0.5gb"
  worker_instance_size = "apps-s-1vcpu-1gb"
  env                  = { DEBUG = "False" }
  secret_env           = { SECRET_KEY = "x" }
}

run "routes_only_backend_prefixes_to_api" {
  command = plan
  assert {
    condition     = [for r in digitalocean_app.this.spec[0].ingress[0].rule : r.match[0].path[0].prefix] == ["/api", "/health", "/static", "/version", "/"]
    error_message = "Ingress must route /api,/health,/static,/version to api and / to frontend (no /admin)."
  }
}

run "single_worker_runs_beat" {
  command = plan
  assert {
    condition     = digitalocean_app.this.spec[0].worker[0].instance_count == 1 && strcontains(digitalocean_app.this.spec[0].worker[0].run_command, " -B ")
    error_message = "Exactly one worker instance, running beat."
  }
}

run "no_skip_collectstatic_env_anywhere" {
  command = plan
  assert {
    # component env blocks are sets: setunion, not concat
    condition     = alltrue([for e in setunion(digitalocean_app.this.spec[0].worker[0].env, digitalocean_app.this.spec[0].job[0].env) : e.key != "SKIP_COLLECTSTATIC"])
    error_message = "The image sets SKIP_COLLECTSTATIC; the spec must not."
  }
}

run "spa_calls_api_same_origin" {
  command = plan
  assert {
    condition     = length([for e in digitalocean_app.this.spec[0].static_site[0].env : e if e.key == "VITE_API_BASE_URL"]) == 0
    error_message = "The SPA uses a same-origin API; no VITE_API_BASE_URL at build time."
  }
}

run "no_domain_block_until_hostname_exists" {
  command = plan
  assert {
    condition     = length(digitalocean_app.this.spec[0].domain) == 0
    error_message = "domain = null must produce no domain block."
  }
}

run "domain_block_when_hostname_set" {
  command = plan
  variables {
    domain = "portal-test.example.rs"
  }
  assert {
    condition     = digitalocean_app.this.spec[0].domain[0].name == "portal-test.example.rs"
    error_message = "domain must produce one PRIMARY domain block."
  }
}

run "secret_envs_are_secret" {
  command = plan
  assert {
    condition     = alltrue([for e in digitalocean_app.this.spec[0].env : e.type == "SECRET" if e.key == "SECRET_KEY"])
    error_message = "secret_env entries must be type SECRET."
  }
}
