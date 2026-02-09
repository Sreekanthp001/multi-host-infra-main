variable "client_name" {
  description = "Name of the client"
  type        = string
}

variable "domain_name" {
  description = "Domain name of the client"
  type        = string
}

variable "priority_index" {
  description = "Priority index for the ALB listener rule"
  type        = number
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "task_definition_arn" {
  description = "ECS task definition ARN"
  type        = string
}

variable "ecs_service_security_group_id" {
  description = "Security group ID for the ECS service"
  type        = string
}

variable "alb_https_listener_arn" {
  description = "ARN of the ALB HTTPS listener"
  type        = string
}
