# nivis – infrastructure (DigitalOcean + Terraform)

Terraform for the nivis veterinary lab portal. Two environments, **test** and **prod**, with
**identical services**: only sizes and retention differ, both are built from the same module and
shipped by the same pipeline.

```
                 ┌──────────────── App Platform app (per environment, region fra) ───────────────┐
 https://<domain>│  /            → frontend  static site, Cloudflare edge CDN (built from GitHub)  │
  (TLS, CDN)     │  /api /admin  → api       Django + Daphne, image from DOCR                      │
                 │  /health /static /version                                                       │
                 │                 worker    Celery worker + beat (single instance)               │
                 │                 migrate   PRE_DEPLOY job: manage.py migrate                     │
                 └──────────────────────────────┬─────────────────────────────────────────────────┘
                                                │ VPC (private)
                   ┌────────────────────────────┼──────────────────────────┐
                   │ Managed PostgreSQL 17      │  Managed Valkey 8         │  firewalls: app + VPC only
                   └────────────────────────────┴──────────────────────────┘
   Spaces fra1: <env>-documents (private, versioned)   Spaces ams3: <env>-backups (private, versioned)
```

## Layout

```
backend.hcl                 shared remote-state settings (Spaces S3 backend, lockfile locking)
bootstrap/                  one-time: create the state bucket (outside Terraform)
modules/
  environment/              composes one full environment – the only module stacks call
  network/                  VPC
  postgres/                 cluster, database, least-privilege user, firewall
  valkey/                   cluster, firewall, cache/broker/result URLs
  storage/                  documents + backups buckets, lifecycle, CORS, bucket-scoped keys
  app/                      App Platform app: static site, api, worker, migrate job, routing, alerts
  monitoring/               uptime check + down / latency / TLS-expiry alerts
stacks/
  global/                   container registry, optional DNS zone (account-wide)
  test/  prod/              identical code; differences live only in terraform.tfvars
.github/workflows/          checks → PR plan (read-only) → apply global → test → prod (approval)
docs/app-deploy.example.yml deploy workflow for the application repo
```

Conventions: one state file per stack · modules pin provider ranges, stacks commit
`.terraform.lock.hcl` (linux/darwin/windows hashes) · every variable/output has a description ·
tfvars contain **no secrets**.

## Cost (list prices, per month)

| | test | prod |
|---|---|---|
| frontend static site + CDN | $0 | $0 |
| api | 0.5 GB · $5 | 1 GB fixed · $10 |
| worker + beat | 0.5 GB · $5 | 0.5 GB · $5 |
| PostgreSQL 1 GB, 1 node | $15 | $15 |
| Valkey 1 GB | $15 | $15 |
| **environment** | **$40** | **$45** |

Shared: Spaces subscription $5 (all buckets, 250 GiB), registry Starter $0. **≈ $90/month.**
Scale by editing `stacks/prod/terraform.tfvars` (e.g. `postgres.node_count = 2` for a standby).

## Security model – no secrets in git, logs or artifacts

| Secret | Created by | Lives in |
|---|---|---|
| DigitalOcean API tokens, Spaces keys for Terraform | human, once | GitHub Environment secrets only |
| `SECRET_KEY`, `JWT_SIGNING_KEY`, `AUDIT_HMAC_KEY` | `random_password` | state + App Platform (encrypted `SECRET` env) |
| DB / Valkey passwords | DigitalOcean | state + App Platform `SECRET` env |
| App Spaces key (documents bucket only) | `digitalocean_spaces_key` | state + App Platform `SECRET` env |
| Email provider API key | human | GitHub secret `EXTRA_SECRET_ENV` → `TF_VAR_extra_secret_env` |

- **State is sensitive** (it contains the values above). It lives in a dedicated private,
  versioned Spaces bucket with lockfile locking; only CI and named operators hold its key.
  No output exposes a secret, and every secret variable/output is `sensitive = true`.
- **No plan files are uploaded** as artifacts (binary plans hold secrets in clear text); PR plans
  show `(sensitive value)` only.
- **Least privilege**: PR plans run in the `plan` environment with a *read-only* token; applies
  run in `global`/`test`/`prod` environments, `prod` gated by required reviewers. The app gets a
  Spaces key scoped to its documents bucket; the backup job a key scoped to the backups bucket.
- **Network**: PostgreSQL and Valkey accept connections only from the app and the VPC range;
  TLS is enforced (`sslmode=require`, `rediss://`). `admin_ip_addresses` is empty by default.
- **Guard rails**: `prevent_destroy` on the database and documents bucket, bucket versioning,
  gitleaks + trivy + tflint in CI and pre-commit, Dependabot for actions and providers.

## First-time setup

1. **Credentials** (DigitalOcean console → API):
   - Terraform token (full access or custom scopes for apps, databases, vpc, projects, registry,
     uptime, domain) and a **read-only** token for PR plans.
   - Spaces key with full access for Terraform (manages buckets and reads/writes state), and a
     read-only Spaces key for PR plans.
   - Deploy token for the app repo: custom scopes `registry` read/write + `app` read/update.
   - Install the DigitalOcean GitHub app on the application repo (the static site builds from it).
2. **State bucket**:
   ```bash
   export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...   # Terraform Spaces key
   ./bootstrap/create-state-bucket.sh nivis-tfstate fra1
   ```
3. **GitHub Environments** in this repo: `plan` (read-only secrets), `global`, `test`, `prod`
   (required reviewers). Secrets per environment: `DIGITALOCEAN_TOKEN`, `SPACES_ACCESS_KEY_ID`,
   `SPACES_SECRET_ACCESS_KEY`, and for test/prod `EXTRA_SECRET_ENV` (JSON map, e.g.
   `{"POSTMARK_SERVER_TOKEN":"..."}`).
4. **Fill the TODOs** in `stacks/*/terraform.tfvars` (domains, repo, sender, alert emails).
5. **Apply** by merging to `main` (or locally: `terraform -chdir=stacks/test init
   -backend-config=../../backend.hcl && terraform -chdir=stacks/test apply`).
6. **Database bootstrap (once per environment)**: PostgreSQL 15+ no longer lets new users create
   objects in `public`, and extensions need an owner. Temporarily add your IP to
   `admin_ip_addresses`, connect as `doadmin`, run, then remove the IP again:
   ```sql
   ALTER DATABASE nivis OWNER TO nivis;
   \c nivis
   ALTER SCHEMA public OWNER TO nivis;
   CREATE EXTENSION IF NOT EXISTS pg_trgm;
   CREATE EXTENSION IF NOT EXISTS btree_gist;
   ```
7. **App repo**: copy `docs/app-deploy.example.yml` to `nivis/.github/workflows/deploy.yml`, set
   `APP_ID` (`terraform output app_id`) and `DIGITALOCEAN_DEPLOY_TOKEN` in its test/prod
   environments. Push an image tagged `:test` before the first deployment succeeds.

## Day-to-day

- **Infrastructure change**: PR → checks + plan comment per stack → merge → global and test apply
  automatically → prod applies after approval.
- **Code release**: merge to `main` in nivis → image `:test` → test deploys. Tag `vX.Y.Z` →
  approval → the same image becomes `:prod`, `release` moves to the tag → prod deploys.

## Open items

- **Email provider** is not wired yet: set `extra_env.EMAIL_BACKEND` and the provider key in
  `EXTRA_SECRET_ENV`. The app currently defaults to Amazon SES, which would need an AWS account
  (and its `AWS_*` variables collide with the Spaces credentials) – Postmark or Brevo via anymail
  is simpler.
- **Backups beyond 7 days**: managed PostgreSQL gives daily backups + 7-day PITR. The backups
  bucket and its scoped key exist; the nightly `pg_dump` job still has to be added to the app.
- **Cross-region copy of documents** (fra1 → ams3) needs a scheduled sync job; Spaces has no
  native replication.
- **Registry Starter** has limited storage; enable garbage collection or move to Basic ($5) if
  pushes start failing.
- **`NUM_PROXIES`**: confirm the real X-Forwarded-For hop count behind App Platform after the
  first deploy (default 1).
- **Test teardown**: `prevent_destroy` also applies to test; remove it deliberately if test must
  be destroyed.
