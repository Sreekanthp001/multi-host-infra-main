variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "clients" {
  description = "Map of dynamic clients hosted on ECS"
  type = map(object({
    domain_name    = string
    github_repo    = string
    container_port = number
    priority       = optional(number)
  }))
}

variable "static_client_configs" {
  type        = map(any)
  description = "Static site domains"
}

variable "forwarding_email" {
  description = "The email address where SES will forward incoming emails"
  type        = string
}

variable "alert_email" {
  description = "The email address for CloudWatch alarm notifications"
  type        = string
}