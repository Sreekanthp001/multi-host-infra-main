output "target_group_arn_suffix" {
  description = "Target group ARN suffix for monitoring"
  value       = aws_lb_target_group.client.arn_suffix
}
