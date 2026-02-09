# Local Adapter for Backward Compatibility
locals {
  client_domains = {
    for k, v in var.clients : k => {
      domain   = v.domain_name
      priority = v.priority
    }
  }
}

# 1. Networking Module
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# 2. ECR Module
module "ecr" {
  source          = "./modules/ecr"
  repository_name = "${var.project_name}-repo"
}

# 3. SES Config Module (Legacy Forwarding)
module "ses_config" {
  source           = "./modules/ses_config"
  project_name     = var.project_name
  client_domains   = local.client_domains
  aws_region       = var.aws_region
  forwarding_email = var.forwarding_email
}

# 3a. New Business Mail Server Module (Primary MX)
module "mail_server" {
  source           = "./modules/mail_server"
  project_name     = var.project_name
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]
  ami_id           = var.mail_server_ami
  key_name         = var.mail_server_key_name
  main_domain      = var.main_domain
}

# 4. Route 53 & ACM Module
# Unified DNS and SSL management for ALL domains (dynamic + static)
module "route53_acm" {
  source              = "./modules/route53_acm"
  domain_names        = concat(
    [for k, v in local.client_domains : v.domain],
    [for k, v in var.static_client_configs : v.domain_name]
  )
  client_domains      = local.client_domains
  static_client_configs = var.static_client_configs
  alb_dns_name        = module.alb.alb_dns_name
  alb_zone_id         = module.alb.alb_zone_id
  verification_tokens = module.ses_config.verification_tokens
  dkim_tokens         = module.ses_config.dkim_tokens
  ses_mx_record       = module.ses_config.ses_mx_record
  mail_from_domains   = module.ses_config.mail_from_domains
  
  # Business Mail Integration
  main_domain         = var.main_domain
  mail_server_ip      = module.mail_server.mail_server_ip

  # CloudFront outputs for static domain routing
  cloudfront_domain_names     = module.static_hosting.cloudfront_domain_names
  cloudfront_hosted_zone_ids  = module.static_hosting.cloudfront_hosted_zone_ids
}

# 5. ALB Module
module "alb" {
  source                  = "./modules/alb"
  project_name            = var.project_name
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  acm_certificate_arn     = module.route53_acm.acm_certificate_arn
  acm_validation_resource = module.route53_acm.acm_validation_id
}

# 6. ECS Module
module "ecs" {
  source             = "./modules/ecs"
  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  alb_sg_id          = module.alb.alb_sg_id
  aws_region         = var.aws_region
  ecr_repository_url = module.ecr.repository_url
  secret_arns        = module.secrets.secret_arns
}

# 7. Client Deployment Module
module "client_deployment" {
  source   = "./modules/client_deployment"
  for_each = local.client_domains

  client_name    = each.key
  domain_name    = each.value.domain
  priority_index = each.value.priority
  
  project_name                  = var.project_name
  vpc_id                        = module.networking.vpc_id
  private_subnets               = module.networking.private_subnets
  ecs_cluster_id                = module.ecs.cluster_id
  ecs_cluster_name              = module.ecs.cluster_name
  task_definition_arn           = module.ecs.task_definition_arn
  ecs_service_security_group_id = module.ecs.ecs_service_sg_id
  alb_https_listener_arn        = module.alb.https_listener_arn
}

# 8. Static Hosting Module
module "static_hosting" {
  source                = "./modules/static_hosting"
  project_name          = var.project_name
  static_client_configs = var.static_client_configs
  acm_certificate_arn   = module.route53_acm.acm_certificate_arn
}

# 9. Monitoring Module
module "monitoring" {
  source                  = "./modules/monitoring"
  project_name            = var.project_name
  alert_email             = var.alert_email
  client_domains          = local.client_domains
  static_client_configs   = var.static_client_configs
  
  ecs_cluster_name            = module.ecs.cluster_name
  alb_arn_suffix              = module.alb.alb_arn_suffix
  target_group_arn_suffix     = { for k, v in module.client_deployment : k => v.target_group_arn_suffix }
  cloudfront_distribution_ids = module.static_hosting.cloudfront_distribution_ids
  lambda_function_name        = module.ses_config.lambda_function_name
}

# 10. Secrets Module
module "secrets" {
  source         = "./modules/secrets"
  project_name   = var.project_name
  client_domains = local.client_domains
}

# 11. WAF Module
module "waf" {
  source       = "./modules/waf"
  project_name = var.project_name
  alb_arn      = module.alb.alb_arn
}