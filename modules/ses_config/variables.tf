variable "project_name" {
  description = "Project name"
  type        = string
}

variable "client_domains" {
  description = "Map of client domains for SES configuration"
  type = map(object({
    domain   = string
    priority = number
  }))
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "forwarding_email" {
  description = "Target email for forwarding"
  type        = string
}
