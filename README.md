# nivis-infra: running nivis on DigitalOcean

Terraform for the nivis veterinary lab portal. Two environments, **test** and **prod**, with the same
services: only sizes and retention differ. Both come from the same module and the same pipeline.

This is the operator guide. It is written for one maintainer (you now, or a successor): every routine task is a
numbered list with the exact commands. If a task is not here, it is not supposed to be done by hand.

```
                 App Platform app per environment (region fra)
 https://<host> ─┬─ /api /health /static /version → api       Django + Daphne, image from the registry
  (TLS + CDN)    │                                  worker    Celery worker + beat, exactly 1 instance
                 │                                  migrate   PRE_DEPLOY job: manage.py migrate
                 └─ everything else               → frontend  static site, built by App Platform from GitHub
                                     │ VPC fra1 (private)
                 Managed PostgreSQL 17  ·  Managed Valkey 8   (open only to the app and the VPC range)
   Spaces fra1: nivis-<env>-documents (private, versioned)   Spaces ams3: nivis-<env>-backups (private, versioned)
```

## Contents

1. [Layout](#layout)
2. [Cost](#cost)
3. [Credentials and secrets](#credentials-and-secrets)
4. [First-time setup](#first-time-setup)
5. [Day-to-day](#day-to-day)
6. [Release, rollback, scale](#release-rollback-scale)
7. [Rotate a token or key](#rotate-a-token-or-key)
8. [Restore the database](#restore-the-database)
9. [Logs](#logs)
10. [Accepted risk on the Free GitHub plan](#accepted-risk-on-the-free-github-plan)
11. [Handover checklist](#handover-checklist)
12. [Open items](#open-items)

## Layout

```
backend.hcl                  shared remote-state settings (Spaces bucket nivis-tfstate, lockfile locking)
bootstrap/                   one-time: create the state bucket (outside Terraform)
modules/                     environment (the only one stacks call), network, postgres, valkey, storage, app, monitoring
stacks/global/               container registry, optional DNS zone (account-wide)
stacks/test/  stacks/prod/   identical code; differences live only in terraform.tfvars
scripts/check.sh             the one quality gate: fmt, validate, module tests, workflow checks, tflint, trivy, gitleaks
.github/workflows/           terraform.yml (checks, PR plans, apply global then test), terraform-prod.yml (manual prod)
```

Rules: one state file per stack; tfvars hold **no secrets**; `prevent_destroy` guards the databases and the documents
bucket. Run `./scripts/check.sh` before every push; it must end with `CHECK OK` (needs Docker). If it fails on
files owned by root left by old docker runs, run `rm -rf stacks/*/.terraform` and retry.

## Cost

List prices per month.

| Component | test | prod |
|---|---|---|
| frontend static site | $0 | $0 |
| api | `apps-s-1vcpu-0.5gb` x1, $5 | `apps-s-1vcpu-1gb-fixed` x1, $10 |
| worker + beat | `apps-s-1vcpu-1gb` x1, $12 | `apps-s-1vcpu-1gb` x1, $12 |
| PostgreSQL 17, `db-s-1vcpu-1gb`, 1 node | $15 | $15 |
| Valkey 8, `db-s-1vcpu-1gb`, 1 node | $15 | $15 |
| **Environment** | **$47** | **$52** |

Shared: Spaces $5 (all buckets) + registry Basic $5. **Total about $109/month.**

Monthly check (5 minutes): open DigitalOcean, Billing, compare with $109; look for stray droplets, databases or
volumes; confirm the billing alert set by the account owner still exists.

## Credentials and secrets

Nothing secret is in git, tfvars, logs, plan comments or artifacts. Everything below is set once as a GitHub
**repository secret** (Settings, Secrets and variables, Actions). DigitalOcean has no OIDC for GitHub, so these are
static credentials: create each with a **1-year expiry** and put the expiry date in your calendar (see
[Rotate a token or key](#rotate-a-token-or-key)).

| Secret (this repo) | What it is | Used by |
|---|---|---|
| `PLAN_DIGITALOCEAN_TOKEN` | API token, **read-only** scopes plus `database:view_credentials` | PR plans |
| `PLAN_SPACES_ACCESS_KEY_ID` / `PLAN_SPACES_SECRET_ACCESS_KEY` | Spaces key, read on `nivis-tfstate` and the env buckets | PR plans |
| `APPLY_DIGITALOCEAN_TOKEN` | API token, custom scopes: app, database, vpc, project, registry, domain, uptime, monitoring | applies |
| `APPLY_SPACES_ACCESS_KEY_ID` / `APPLY_SPACES_SECRET_ACCESS_KEY` | Spaces key, full access (creates buckets, writes state) | applies |
| `TEST_EXTRA_SECRET_ENV` | JSON map of app secrets for test | test apply |
| `PROD_EXTRA_SECRET_ENV` | JSON map of app secrets for prod | prod apply |

Example value of `TEST_EXTRA_SECRET_ENV` / `PROD_EXTRA_SECRET_ENV` (one line of JSON; later also `SENTRY_DSN`):

```json
{"RESEND_API_KEY":"re_xxxxxxxxxxxxxxxx"}
```

In the **app repo** (`nivis`): secrets `TEST_DO_DEPLOY_TOKEN` and `PROD_DO_DEPLOY_TOKEN` (custom scopes: registry
read/write, app read/update); variables `TEST_APP_ID`, `PROD_APP_ID`, `DO_REGISTRY`.

Notes:

- The exact token scope lists are finalised during the first test apply: start broad on test, narrow until applies
  still pass, then record the final list **here** (replace this note).
- The read-only plan token needs `database:view_credentials`. Without it every PR plan shows an app update.
- The plan Spaces key can only read buckets that exist. After the **first** apply of each environment, grant the plan
  key read access to the new env buckets (documents in fra1 and backups in ams3) in the DigitalOcean console, then
  open a PR and confirm the plan refreshes them. If a read grant cannot read bucket configuration, use a full-access
  key for plans and record that here.
- Every app env value is a secret to Terraform, so plans show `(sensitive value)` for all of them. To review an env
  change, do not read the plan: run `terraform -chdir=stacks/test output runtime_env` (non-secret values) and
  `terraform -chdir=stacks/test output secret_env_keys` (names only) before and after, with the apply credentials
  exported as `DIGITALOCEAN_TOKEN`, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` after
  `terraform -chdir=stacks/test init -backend-config=../../backend.hcl`.

## First-time setup

Do these in order. The GitHub organization and DigitalOcean team belong to NIVNS (you are Owner on GitHub, Member on
DigitalOcean); Resend belongs to NIVNS.

### 1. Accounts and repositories

1. Create the GitHub organization (Free plan) and add yourself as Owner. Create two private repos: `nivis` (app) and
   `nivis-infra` (this repo). Push **`nivis` first**, before any secrets, the GitHub app install or the
   `github_repo` tfvar.
2. In DigitalOcean (NIVNS team) create the tokens and Spaces keys from the table above, each with a 1-year expiry.
   Also create `TEST_DO_DEPLOY_TOKEN` and `PROD_DO_DEPLOY_TOKEN`.
3. Add every secret from the table to the `nivis-infra` repo, and the deploy tokens to the `nivis` repo.
4. Install the **DigitalOcean GitHub app** on the `nivis` repo (DigitalOcean console: Apps, Create App, GitHub,
   authorise and select only `nivis`; then cancel the wizard). The static site is built from that repo, so without
   the install the first apply fails.
5. In the `nivis` repo set the variable `DO_REGISTRY` to the registry name (`nivis`, from
   `stacks/global/terraform.tfvars`).

### 2. State bucket (once, from your machine)

Needs the AWS CLI v2 and the full-access Spaces key (the `APPLY_SPACES_*` one).

```bash
export AWS_ACCESS_KEY_ID=...   AWS_SECRET_ACCESS_KEY=...
./bootstrap/create-state-bucket.sh nivis-tfstate fra1
```

### 3. Fill the tfvars

Edit `stacks/test/terraform.tfvars` and `stacks/prod/terraform.tfvars`: `github_repo` (`<org>/nivis`), `lab` (name,
short name, address), `default_from_email`, `alert_emails`. Leave `domain = null` until NIVNS decides the hostnames
(see DNS handoff). Commit via a PR as in [Day-to-day](#day-to-day).

### 4. Bootstrap order, test

The App Platform app waits for its first deployment, so the image and the source branch must exist **before** the
first test apply.

1. Merge to `main`: `terraform.yml` applies `global` (registry) first, then tries `test`. If `test` fails because
   the image or branch does not exist, that is expected; carry on.
2. In the `nivis` repo: Actions, **deploy**, Run workflow on `main`. It builds and pushes `backend:<sha>` and
   `backend:test`, creates the `test` branch, and skips the deployment while `TEST_APP_ID` is unset.
3. In `nivis-infra`: Actions, **terraform**, re-run the failed `apply-test` job (or push any small change to `main`).
4. Open the finished job's **summary**. It lists `app_id` and `default_ingress`. Copy `app_id` into the `nivis` repo
   variable `TEST_APP_ID` (Settings, Secrets and variables, Actions, Variables).
5. Open the `default_ingress` URL and check the app loads.

### 5. Checks on test before prod

- Read the real `X-Forwarded-For` chain behind App Platform and set `num_proxies` in the tfvars to match.
- Confirm the public-URL envs resolve at runtime: `terraform output runtime_env` shows the `${APP_URL}` /
  `${APP_DOMAIN}` bindables; log in through the default URL and check there are no CORS or CSRF errors.
- Right after an apply, a PR plan for test says "No changes".
- Confirm the static-site build did not need an API URL (the SPA calls `/api` on the same host).
- Enable registry garbage collection (DigitalOcean console, Container Registry, Settings); keep the last 10 `v*` tags
  and the moving `test`/`prod` tags.
- Once the Resend sending domain is verified (needs the DNS records from IT), send one email of each type and
  confirm SPF and DKIM pass. Until then email on test is expected to fail; the app retries.

### 6. Bootstrap order, prod

Same idea, with the first release tag.

1. In `nivis`: `git tag v0.1.0 && git push --tags` (on a commit of `main`). The deploy workflow re-tags the image as
   `:prod`, creates the `release` branch and skips the deployment while `PROD_APP_ID` is unset.
2. In `nivis-infra`: Actions, **terraform-prod**, Run workflow (branch `main`).
3. Copy `app_id` from that job's summary into the `nivis` repo variable `PROD_APP_ID`.

### 7. Database one-time SQL (once per environment)

PostgreSQL 15+ stops new users creating objects in `public`, and extensions need an owner. Temporarily add your IP,
connect as `doadmin`, run the SQL, then remove the IP.

1. Set `admin_ip_addresses = ["<your.public.ip>/32"]` in the stack's tfvars, PR, merge (test applies; for prod run
   terraform-prod).
2. Get the connection string: `doctl databases list`, then `doctl databases connection <cluster-id>` (use the
   `doadmin` URI, port 25060).
3. Connect with `psql "<doadmin URI>"` and run:
   ```sql
   ALTER DATABASE nivis OWNER TO nivis;
   \c nivis
   ALTER SCHEMA public OWNER TO nivis;
   CREATE EXTENSION IF NOT EXISTS pg_trgm;
   CREATE EXTENSION IF NOT EXISTS btree_gist;
   ```
4. Remove `admin_ip_addresses` again (back to `[]`), PR, merge/apply.
5. Redeploy the app (see Release) so `migrate` runs against the prepared database.

### 8. DNS handoff (when NIVNS decides the hostnames)

Both environments run on their `nivis-<env>-xxxx.ondigitalocean.app` address until then. DNS stays with NIVNS IT.

1. Send IT one request per environment: a **CNAME** with **TTL 300**:
   ```
   portal.<nivns-domain>.        300  IN CNAME  <prod default_ingress host>.
   portal-test.<nivns-domain>.   300  IN CNAME  <test default_ingress host>.
   ```
   The host is the `default_ingress` value from the apply summary, without `https://`. Ask IT to check the domain's
   CAA records (if any): they must allow **Let's Encrypt** (`0 issue "letsencrypt.org"`).
2. When IT confirms the records, set `domain = "portal-test.<nivns-domain>"` in `stacks/test/terraform.tfvars` (prod
   likewise), PR, merge. One apply, no other change: the app's URL settings follow the domain automatically.
3. App Platform issues and renews the certificate. Check `live_url` with `terraform output live_url`.

## Day-to-day

**Change infrastructure.**

1. `git switch -c my-change`, edit, `./scripts/check.sh` (must print `CHECK OK`), push, open a PR.
2. The PR shows checks and one plan comment per stack (global, test, prod). Read them.
3. Merge to `main`: `global` then `test` apply automatically.
4. **Prod**: GitHub, Actions, **terraform-prod**, **Run workflow** (branch `main`). It plans and applies prod. Do this
   only after reading the prod plan in the merged PR. It refuses to run from any other branch.

Two applies at once on the same stack are safe: the second waits on the Spaces lockfile.

## Release, rollback, scale

**Release the app.**

- Test: every merge to `main` in `nivis` deploys to test (image `:test`, `test` branch).
- Prod: in `nivis`, on a commit of `main`:
  ```bash
  git tag vX.Y.Z && git push --tags
  ```
  The same already-built image becomes `:prod` and `:vX.Y.Z`, the `release` branch moves to the tag, prod deploys.

**Roll back.** Before go-live the no-cleanup policy applies (just fix forward).

1. In `nivis`: Actions, **deploy**, re-run the workflow for the previous good tag (or, on test, for the last good
   commit). The image is not rebuilt.
2. After go-live, a release whose migration is **not backward-compatible** cannot be rolled back this way: restore the
   database from a point-in-time backup instead (see [Restore the database](#restore-the-database)), then redeploy
   the previous tag.

**Scale.** Sizes are tfvars: edit `app.api_instance_size`, `app.api_instance_count`, `app.worker_instance_size`,
`postgres.size`, `postgres.node_count` (2 adds a standby, +$15), `valkey.*` in `stacks/<env>/terraform.tfvars`, then
follow Day-to-day. Keep **one** worker instance: it runs the Celery beat scheduler. Update the cost table above.

## Rotate a token or key

Do this for every secret before its 1-year expiry, and on handover.

1. Create the new token or Spaces key in DigitalOcean with the same scopes and a 1-year expiry.
2. Replace the matching GitHub secret (infra repo for `PLAN_*` and `APPLY_*`; app repo for `*_DO_DEPLOY_TOKEN`).
3. Run a workflow that uses it (open a PR for the plan secrets; Run workflow for deploy and apply secrets) and check
   it passes.
4. Delete the old token or key in DigitalOcean.
5. App secrets from `*_EXTRA_SECRET_ENV` (e.g. `RESEND_API_KEY`): create the new key at the provider, update the
   GitHub secret, merge any change (test) or Run workflow terraform-prod (prod), then revoke the old key.
6. The app's own Spaces keys (documents and backups) are Terraform resources (`digitalocean_spaces_key.app` and
   `.backup` in the storage module). To rotate one, apply with `-replace` from your machine, with the apply
   credentials exported:
   ```bash
   terraform -chdir=stacks/test init -backend-config=../../backend.hcl
   terraform -chdir=stacks/test apply -replace='module.environment.module.storage.digitalocean_spaces_key.app'
   ```
   Review the plan first; it redeploys the app with the new key. Do test, check it, then prod.

## Restore the database

Managed PostgreSQL keeps daily backups with 7-day point-in-time recovery. A restore **creates a new cluster**; the
Terraform-managed cluster is never swapped, so state does not change. Copy the data back instead.

1. DigitalOcean console, Databases, the env's cluster, Backups, **Restore from backup** to a new cluster
   (`nivis-<env>-restore`), choosing the point in time. Wait until it is online.
2. Add your IP temporarily to `admin_ip_addresses` (as in the one-time SQL) so you can reach the Terraform-managed
   cluster, and to the restore cluster's trusted sources in the console.
3. Get both connection strings: `doctl databases list`, then `doctl databases connection <cluster-id>`.
4. Stop writes: scale the worker and api down to 0 via the console, or accept a short window of users reading only.
5. Copy:
   ```bash
   pg_dump --format=custom --no-owner --dbname "<restore cluster doadmin URI for nivis>" -f nivis.dump
   pg_restore --clean --if-exists --no-owner --role=nivis --dbname "<managed cluster doadmin URI for nivis>" nivis.dump
   ```
6. Check the app, remove the temporary IP from tfvars (PR, apply), delete the restore cluster in the console, delete
   `nivis.dump`.

The documents bucket is versioned: an overwritten or deleted document can be recovered from its previous version.
Terraform state is versioned too (old versions kept 90 days) in `nivis-tfstate`.

## Logs

Find the app id: `doctl apps list` (or `terraform -chdir=stacks/test output app_id`).

```bash
doctl apps logs <app-id> api --type run --follow       # api runtime logs
doctl apps logs <app-id> worker --type run --follow    # celery worker + beat
doctl apps logs <app-id> migrate --type run            # the PRE_DEPLOY migrate job
doctl apps logs <app-id> api --type build              # build logs
doctl apps list-deployments <app-id>                   # recent deployments and phases
```

The uptime check on `live_url` emails `alert_emails` when the site is down, slow or its certificate is about to expire.

## Accepted risk on the Free GitHub plan

The Free plan has no Environments and no required reviewers. Repository secrets, including `APPLY_*`, are readable by
any workflow on any branch. Prod is gated by an explicit **Run workflow** button on `main`, re-checked inside the
reusable apply workflow, but a branch that edits both workflow files could still use the apply credentials. This is
accepted because you are the only writer and use 2FA. Dependabot PRs get no secrets, so their plans are skipped.

**Removing the risk:** upgrade the organization to GitHub **Team** ($4 per user per month, recommended before
go-live). Then move the `APPLY_*`, `*_EXTRA_SECRET_ENV` and `PROD_DO_DEPLOY_TOKEN` secrets into protected
Environments with required reviewers, and add a ruleset for `v*` tags. No other change is needed.

## Handover checklist

1. Add the successor as GitHub org Owner and DigitalOcean team member (with the roles they need).
2. Rotate **every** token and key in [Credentials and secrets](#credentials-and-secrets), including the Resend key
   and (later) the Sentry DSN. Tokens are tied to the person who created them: delete the old ones.
3. Confirm the DigitalOcean billing alert and the `alert_emails` recipients are the right people.
4. Transfer ownership of the GitHub repos, the DigitalOcean team and the Resend account to NIVNS if not already.
5. Walk the successor through one release to test, one prod release, and the restore section.
6. Record the final token scope lists in this README.

## Open items

Outside this repo, tracked and not built here:

- **First data in a fresh environment**: species, places, units, areas, tiers and roles arrive with `migrate`. The
  institute catalogue (`catalog/data/institute/*.csv`) and the first lab admin account do not. To decide: a one-time
  loader command, or the app's import screens plus `createsuperuser`.
- **Resend split between test and prod**: sender address, account and the shared free quota (100/day).
- Nightly `pg_dump` to the backups bucket (managed backups give 7-day PITR until then); document purge job;
  cross-region document copy; Resend bounce handling; Sentry SDK.
- Final hostnames and the NIVNS domain name.
- GitHub Team upgrade before go-live.
- Final token scope lists (see Credentials and secrets).
