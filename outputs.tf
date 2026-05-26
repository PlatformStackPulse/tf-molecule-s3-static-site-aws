# --- Bucket Core ---
output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = module.bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.bucket.bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket (for CloudFront origin)"
  value       = module.bucket.bucket_regional_domain_name
}

# --- Website ---
output "website_endpoint" {
  description = "S3 website endpoint URL"
  value       = try(module.website_configuration.website_endpoint, null)
}

output "website_domain" {
  description = "S3 website domain (for Route53 alias)"
  value       = try(module.website_configuration.website_domain, null)
}
