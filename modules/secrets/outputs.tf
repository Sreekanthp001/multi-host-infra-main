output "secret_arns" {
  description = "List of ARNs for client secrets"
  value       = [for s in aws_secretsmanager_secret.client : s.arn]
}
