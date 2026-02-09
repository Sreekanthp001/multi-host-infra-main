variable "project_name" {
  description = "Project name"
  type        = string
}

variable "static_client_configs" {
  description = "Map of static client configurations"
  type        = map(any)
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  type        = string
}
