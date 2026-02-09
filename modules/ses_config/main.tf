resource "aws_ses_domain_identity" "client" {
  for_each = var.client_domains
  domain   = each.value.domain
}

resource "aws_ses_domain_dkim" "client" {
  for_each = var.client_domains
  domain   = aws_ses_domain_identity.client[each.key].domain
}

resource "aws_ses_domain_mail_from" "client" {
  for_each         = var.client_domains
  domain           = aws_ses_domain_identity.client[each.key].domain
  mail_from_domain = "mail.${each.value.domain}"
}

# Inbound rules (simplified for now, usually requires S3 and Lambda)
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "${var.project_name}-receipt-rules"
}

resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}
