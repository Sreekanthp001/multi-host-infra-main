variable "domain_names" {
  description = "List of all domain names"
  type        = list(string)
}

variable "client_domains" {
  description = "Map of dynamic client domains"
  type        = map(any)
}

variable "static_client_configs" {
  description = "Map of static client configurations"
  type        = map(any)
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID"
  type        = string
}

variable "verification_tokens" {
  description = "SES verification tokens map"
  type        = map(string)
}

variable "dkim_tokens" {
  description = "SES DKIM tokens map"
  type        = map(list(string))
}

variable "ses_mx_record" {
  description = "SES MX record value"
  type        = string
}

variable "mail_from_domains" {
  description = "SES MAIL FROM domains map"
  type        = map(string)
}

variable "main_domain" {
  description = "Primary domain for the platform"
  type        = string
}

variable "mail_server_ip" {
  description = "Public IP of the mail server"
  type        = string
}

variable "cloudfront_domain_names" {
  description = "Map of CloudFront domain names"
  type        = map(string)
}

variable "cloudfront_hosted_zone_ids" {
  description = "Map of CloudFront hosted zone IDs"
  type        = map(string)
}
