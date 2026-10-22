terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.60"
    }
  }

  backend "s3" {
    key = "test/terraform.tfstate"
  }
}
