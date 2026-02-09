output "cloudfront_domain_names" {
  description = "Map of CloudFront domain names"
  value       = { for k, v in aws_cloudfront_distribution.s3_dist : k => v.domain_name }
}

output "cloudfront_hosted_zone_ids" {
  description = "Map of CloudFront hosted zone IDs"
  value       = { for k, v in aws_cloudfront_distribution.s3_dist : k => v.hosted_zone_id }
}

output "cloudfront_distribution_ids" {
  description = "Map of CloudFront distribution IDs"
  value       = { for k, v in aws_cloudfront_distribution.s3_dist : k => v.id }
}
