# --- Documents: PDF requests and test reports -------------------------------------------------
resource "digitalocean_spaces_bucket" "documents" {
  name          = "${var.name_prefix}-documents"
  region        = var.region
  acl           = "private"
  force_destroy = false

  # Versioning keeps every overwritten or deleted report recoverable (Spaces has no Object Lock).
  versioning {
    enabled = true
  }

  lifecycle_rule {
    id                                     = "housekeeping"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 7

    noncurrent_version_expiration {
      days = var.noncurrent_version_retention_days
    }
  }

  dynamic "lifecycle_rule" {
    # Test environment only: documents are disposable.
    for_each = var.document_expiration_days == null ? [] : [var.document_expiration_days]
    content {
      id      = "expire-documents"
      enabled = true

      expiration {
        days = lifecycle_rule.value
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "digitalocean_spaces_bucket_cors_configuration" "documents" {
  bucket = digitalocean_spaces_bucket.documents.id
  region = var.region

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["*"]
    max_age_seconds = 3600
  }
}

# --- Backups: database dumps, stored in a second region --------------------------------------
resource "digitalocean_spaces_bucket" "backups" {
  name          = "${var.name_prefix}-backups"
  region        = var.backup_region
  acl           = "private"
  force_destroy = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id                                     = "retention"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 7

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      days = 7
    }
  }
}

# --- Access keys: one per consumer, scoped to a single bucket ---------------------------------
resource "digitalocean_spaces_key" "app" {
  name = "${var.name_prefix}-app"

  grant {
    bucket     = digitalocean_spaces_bucket.documents.name
    permission = "readwrite"
  }
}

resource "digitalocean_spaces_key" "backup" {
  name = "${var.name_prefix}-backup"

  grant {
    bucket     = digitalocean_spaces_bucket.backups.name
    permission = "readwrite"
  }
}
