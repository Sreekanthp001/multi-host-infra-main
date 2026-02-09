# root/outputs.tf

output "alb_dns_name" {
  description = "The DNS name of the Load Balancer"
  value       = module.alb.alb_dns_name
}

output "cloudfront_urls" {
  description = "CloudFront URLs for static hosting clients"
  value       = module.static_hosting.cloudfront_domain_names
}

output "route53_nameservers" {
  description = "Name servers for the created hosted zones (Update these at your Domain Registrar)"
  value       = module.route53_acm.name_servers
}

output "ecr_repository_url" {
  description = "ECR Repository URL for Docker push"
  value       = module.ecr.repository_url
}

output "mail_server_ip" {
  description = "Business Mail Server Public IP"
  value       = module.mail_server.mail_server_ip
}

output "mail_server_hostname" {
  description = "Primary MX Hostname"
  value       = module.mail_server.mail_server_hostname
}