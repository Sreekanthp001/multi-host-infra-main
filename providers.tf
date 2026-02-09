# root/providers.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Remote State Management
  backend "s3" {
    bucket         = "sree84s-tf-remote-state-111" # Ensure this bucket exists in the new account
    key            = "multi-host-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table" # Locking for team collaboration
  }
}

provider "aws" {
  region = var.aws_region
}

# Alias provider for CloudFront/ACM requirements (Global resources)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}