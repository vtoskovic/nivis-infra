# Shared remote-state settings (DigitalOcean Spaces via the S3 backend). Not secret.
# Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (a Spaces key scoped to this bucket).
# Each stack sets its own `key` in versions.tf.
#
#   terraform init -backend-config=../../backend.hcl

bucket = "nivis-tfstate"
region = "us-east-1" # ignored by Spaces, required by the S3 backend

endpoints = {
  s3 = "https://fra1.digitaloceanspaces.com"
}

use_lockfile                = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_s3_checksum            = true
