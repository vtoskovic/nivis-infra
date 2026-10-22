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
tf() { run hashicorp/terraform:1.13 "$@"; }

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
