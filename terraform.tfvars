# root/terraform.tfvars

project_name     = "venturemond-infra"
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
forwarding_email = "sreekanthpaleti1999@gmail.com"
alert_email      = "sreekanthpaleti1999@gmail.com"

# New non-hardcoded variables
main_domain          = "webhizzy.in"
mail_server_ami      = "ami-0522ab6e1ddcc7055" # Ubuntu 22.04 LTS
mail_server_key_name = "webhizzy-prod"

# 1. Dynamic Domain (ECS based)
clients = {
  "sree84s" = {
    domain_name    = "sree84s.site"
    github_repo    = "https://github.com/Sreekanthp001/vm2-modern-portfolio.git"
    container_port = 80
    priority       = 100
  }
  "mounika" = {
    domain_name    = "mounikaindyala.fun"
    github_repo    = "https://github.com/Sreekanthp001/vm-organic-food-store.git"
    container_port = 80
    priority       = 110
  }
}

# 2. Static Domain (S3 + CloudFront based)
static_client_configs = {
  "calvio-sub" = {
    domain_name      = "calvio.sree84s.site"
    parent_zone_name = "sree84s.site"
  }
}
