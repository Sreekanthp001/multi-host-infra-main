# root/terraform.tfvars

project_name     = "venturemond-infra"
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
forwarding_email = "sreekanthpaleti1999@gmail.com"
alert_email      = "sreekanthpaleti1999@gmail.com"

# 1. Dynamic Domain (ECS based)
clients = {
  "sree84s" = {
    domain_name    = "sree84s.site"
    github_repo    = "https://github.com/Sreekanthp001/vm2-modern-portfolio.git"
    container_port = 80
    priority       = 100
  }
}
# 2. Static Domain (S3 + CloudFront based)
static_client_configs = {
  /* "clavio" = {
    domain_name = "clavio.store"
  } */
  "calvio-sub" = {
    domain_name      = "calvio.sree84s.site"
    parent_zone_name = "sree84s.site"
  }
}

#forwarding_email = "sreekanthpaleti1999@gmail.com"
