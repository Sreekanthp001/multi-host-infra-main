variable "project_name" {
  description = "Project name"
  type        = string
}

variable "client_domains" {
  description = "Map of dynamic client domains"
  type        = map(any)
}
