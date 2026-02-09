output "verification_tokens" {
  description = "Verification tokens for client domains"
  value       = { for k, v in aws_ses_domain_identity.client : k => v.verification_token }
}

output "dkim_tokens" {
  description = "DKIM tokens for client domains"
  value       = { for k, v in aws_ses_domain_dkim.client : k => v.dkim_tokens }
}

output "mail_from_domains" {
  description = "MAIL FROM domains for clients"
  value       = { for k, v in aws_ses_domain_mail_from.client : k => v.mail_from_domain }
}

output "ses_mx_record" {
  description = "SES MX record endpoint"
  value       = "inbound-smtp.${var.aws_region}.amazonaws.com"
}

output "lambda_function_name" {
  description = "Name of the bounce handler Lambda function (placeholder)"
  value       = "placeholder-func"
}
