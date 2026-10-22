mock_provider "digitalocean" {}

variables {
  name_prefix   = "nivis-test"
  region        = "fra1"
  backup_region = "ams3"
}

run "documents_versioned" {
  command = plan
  assert {
    condition     = digitalocean_spaces_bucket.documents.versioning[0].enabled == true && digitalocean_spaces_bucket.documents.acl == "private"
    error_message = "The documents bucket must be private and versioned."
  }
}

run "app_key_scoped_to_documents" {
  command = plan
  assert {
    condition     = digitalocean_spaces_key.app.grant[0].bucket == "nivis-test-documents" && digitalocean_spaces_key.app.grant[0].permission == "readwrite"
    error_message = "The app key must be readwrite on the documents bucket only."
  }
}

run "backup_region_must_differ" {
  command = plan
  variables {
    backup_region = "fra1"
  }
  expect_failures = [var.backup_region]
}
