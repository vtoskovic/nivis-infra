output "vpc_id" {
  description = "VPC UUID."
  value       = digitalocean_vpc.this.id
}

output "vpc_urn" {
  description = "VPC URN."
  value       = digitalocean_vpc.this.urn
}

output "ip_range" {
  description = "VPC CIDR."
  value       = digitalocean_vpc.this.ip_range
}
