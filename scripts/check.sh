#!/usr/bin/env bash
# One-command quality gate: fmt, validate, module tests, tflint, trivy, gitleaks.
# Runs everything in Docker from the repo root; exit 0 means every gate passed.
set -euo pipefail
export MSYS_NO_PATHCONV=1

cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p .tfcache

run() {
  local image=$1
  shift
  docker run --rm --user "$(id -u):$(id -g)" \
    -e HOME=/tmp -e TF_PLUGIN_CACHE_DIR=/w/.tfcache -e TFLINT_PLUGIN_DIR=/w/.tfcache/tflint \
    -v "$PWD:/w" -w /w "$image" "$@"
}
tf() { run hashicorp/terraform:1.13.4 "$@"; }

echo "== terraform fmt"
tf fmt -recursive -check -diff

for stack in stacks/*/; do
  stack=${stack%/}
  echo "== validate $stack"
  tf -chdir="$stack" init -backend=false -input=false >/dev/null
  tf -chdir="$stack" validate
done

for module in modules/*/; do
  module=${module%/}
  [ -d "$module/tests" ] || continue
  echo "== test $module"
  tf -chdir="$module" init -backend=false -input=false >/dev/null
  tf -chdir="$module" test
done

echo "== storage: no CORS (presigned downloads)"
if grep -rq cors_configuration modules/storage; then
  echo "modules/storage must not declare a CORS configuration; documents are served via presigned URLs" >&2
  exit 1
fi

echo "== workflows (Task A6: Free plan, no Environments, pinned actions)"
wf_fail=0
wf_expect() { echo "WORKFLOW CHECK FAILED: $1" >&2; wf_fail=1; }
if grep -rEn '^[[:space:]]*environment:' .github/workflows; then
  wf_expect "no 'environment:' key is allowed (GitHub Free has no Environments)"
fi
grep -Eq '^on:' .github/workflows/terraform-prod.yml 2>/dev/null &&
  grep -Eq '^  workflow_dispatch:' .github/workflows/terraform-prod.yml ||
  wf_expect "terraform-prod.yml must be triggered by workflow_dispatch"
if [ -f .github/workflows/terraform-prod.yml ] && grep -Eq '^  (push|pull_request|schedule):' .github/workflows/terraform-prod.yml; then
  wf_expect "terraform-prod.yml must be workflow_dispatch only"
fi
grep -Eq "if: github\.ref == 'refs/heads/main'" .github/workflows/terraform-prod.yml 2>/dev/null ||
  wf_expect "terraform-prod.yml job must have if: github.ref == 'refs/heads/main'"
if grep -En 'stack: *prod' .github/workflows/terraform.yml; then
  wf_expect "terraform.yml must apply only global and test"
fi
grep -Eq 'stack: *global' .github/workflows/terraform.yml 2>/dev/null &&
  grep -Eq 'stack: *test' .github/workflows/terraform.yml ||
  wf_expect "terraform.yml must apply global and test"
unpinned=$(grep -rhE '^[[:space:]-]*uses:' .github/workflows | grep -v 'uses: \./' | grep -Ev '@[0-9a-f]{40}( |$)' || true)
if [ -n "$unpinned" ]; then
  echo "$unpinned" >&2
  wf_expect "every uses: must be pinned to a 40-character commit SHA"
fi
awk '/^  plan:/{p=1;next} /^  [a-z-]+:/{p=0} p' .github/workflows/terraform.yml | grep -q 'TF_VAR_extra_secret_env' ||
  wf_expect "terraform.yml plan job must set TF_VAR_extra_secret_env"
[ "$wf_fail" -eq 0 ] || exit 1
run rhysd/actionlint:latest

echo "== tfvars invariants (frontend branches, registry tier)"
tfvars_fail=0
# expect_tfvar FILE KEY RHS: the file must contain a line "KEY = RHS" (RHS taken literally).
expect_tfvar() {
  local file=$1 key=$2 rhs=$3
  if ! grep -Eq "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*${rhs}([[:space:]]|#|\$)" "$file"; then
    echo "MISMATCH $file: expected $key = $rhs" >&2
    tfvars_fail=1
  fi
}
expect_tfvar stacks/test/terraform.tfvars frontend_branch '"test"'
expect_tfvar stacks/prod/terraform.tfvars frontend_branch '"release"'
expect_tfvar stacks/global/terraform.tfvars registry_tier '"basic"'
if [ "$tfvars_fail" -ne 0 ]; then
  echo "tfvars invariants violated; fix the MISMATCH lines above" >&2
  exit 1
fi

echo "== tflint"
mkdir -p .tfcache/tflint
run ghcr.io/terraform-linters/tflint --init --config /w/.tflint.hcl >/dev/null
run ghcr.io/terraform-linters/tflint --recursive --config /w/.tflint.hcl

echo "== trivy"
run aquasec/trivy config --severity HIGH,CRITICAL --exit-code 1 /w

echo "== gitleaks"
run zricethezav/gitleaks dir /w --config /w/.gitleaks.toml

rm -rf stacks/*/.terraform modules/*/.terraform modules/*/.terraform.lock.hcl

echo "CHECK OK"
