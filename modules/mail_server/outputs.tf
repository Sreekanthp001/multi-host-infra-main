output "mail_server_ip" {
  description = "Public IP of the mail server"
  value       = aws_eip.mail_server.public_ip
}

output "mail_server_hostname" {
  description = "Hostname of the mail server"
  value       = "mx.${var.main_domain}"
}
