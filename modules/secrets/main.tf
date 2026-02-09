resource "aws_secretsmanager_secret" "client" {
  for_each = var.client_domains
  name     = "${var.project_name}/${each.key}/secrets"
  
  recovery_window_in_days = 0 # For testing purposes
}

resource "aws_secretsmanager_secret_version" "client" {
  for_each  = var.client_domains
  secret_id = aws_secretsmanager_secret.client[each.key].id
  secret_string = jsonencode({
    API_KEY = "placeholder-key"
    DB_URL  = "placeholder-url"
  })
}
