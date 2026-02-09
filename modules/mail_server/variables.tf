variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the mail server"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the mail server"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "main_domain" {
  description = "Primary domain for the mail server"
  type        = string
}
