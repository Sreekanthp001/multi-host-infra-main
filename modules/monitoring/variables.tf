variable "project_name" {
  description = "Project name"
  type        = string
}

variable "alert_email" {
  description = "Email to receive monitor alerts"
  type        = string
}

variable "client_domains" {
  description = "Map of dynamic client domains"
  type        = map(any)
}

variable "static_client_configs" {
  description = "Map of static client configurations"
  type        = map(any)
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Map of target group ARN suffixes"
  type        = map(string)
}

variable "cloudfront_distribution_ids" {
  description = "Map of CloudFront distribution IDs"
  type        = map(string)
}

variable "lambda_function_name" {
  description = "Name of the SES lambda function"
  type        = string
}
