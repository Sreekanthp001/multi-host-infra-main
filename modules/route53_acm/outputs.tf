output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_validation_id" {
  description = "The ID of the ACM certificate validation resource"
  value       = aws_acm_certificate_validation.main.id
}

output "name_servers" {
  description = "Map of domain names to their Route53 name servers"
  value       = { for k, v in aws_route53_zone.client_zones : k => v.name_servers }
}
