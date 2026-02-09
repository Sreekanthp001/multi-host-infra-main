# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_names[0]
  subject_alternative_names = slice(var.domain_names, 1, length(var.domain_names))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 Zones and Records
resource "aws_route53_zone" "client_zones" {
  for_each = toset(var.domain_names)
  name     = each.key
}

# DNS Validation records
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
      zone   = dvo.domain_name
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.client_zones[each.value.zone].zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

# ALB Alias records for dynamic clients
resource "aws_route53_record" "alb_alias" {
  for_each = var.client_domains
  zone_id  = aws_route53_zone.client_zones[each.value.domain].zone_id
  name     = each.value.domain
  type     = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# CloudFront Alias records for static clients
resource "aws_route53_record" "cf_alias" {
  for_each = var.static_client_configs
  zone_id  = aws_route53_zone.client_zones[each.value.domain_name].zone_id
  name     = each.value.domain_name
  type     = "A"

  alias {
    name                   = var.cloudfront_domain_names[each.key]
    zone_id                = var.cloudfront_hosted_zone_ids[each.key]
    evaluate_target_health = false
  }
}

# SES Records
resource "aws_route53_record" "ses_txt" {
  for_each = var.verification_tokens
  zone_id  = aws_route53_zone.client_zones[each.key].zone_id
  name     = "_amazonses.${each.key}"
  type     = "TXT"
  ttl      = "600"
  records  = [each.value]
}

resource "aws_route53_record" "ses_dkim" {
  for_each = {
    for pair in flatten([
      for domain, tokens in var.dkim_tokens : [
        for i, token in tokens : {
          domain = domain
          token  = token
          index  = i
        }
      ]
    ]) : "${pair.domain}-${pair.index}" => pair
  }

  zone_id = aws_route53_zone.client_zones[each.value.domain].zone_id
  name    = "${each.value.token}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${each.value.token}.dkim.amazonses.com"]
}

# MX Record for SES
resource "aws_route53_record" "mx" {
  for_each = var.client_domains
  zone_id  = aws_route53_zone.client_zones[each.value.domain].zone_id
  name     = each.value.domain
  type     = "MX"
  ttl      = "600"
  records  = ["10 ${var.ses_mx_record}"]
}

# Business Mail Server A Record
resource "aws_route53_record" "mail_server_a" {
  zone_id = aws_route53_zone.client_zones[var.main_domain].zone_id
  name    = "mx.${var.main_domain}"
  type    = "A"
  ttl     = "600"
  records = [var.mail_server_ip]
}
