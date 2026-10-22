# Credentials are read from the environment only – never from variables or files:
#   DIGITALOCEAN_TOKEN, SPACES_ACCESS_KEY_ID, SPACES_SECRET_ACCESS_KEY
provider "digitalocean" {}
