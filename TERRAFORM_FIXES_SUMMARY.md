# Terraform Fixes Summary

## Overview
This document summarizes the three critical fixes applied to the `venturemond-infra` multi-tenant infrastructure to resolve errors during `terraform apply`.

---

## Fix 1: EC2 Duplicate Security Group Error

### Problem
**Error**: `InvalidGroup.Duplicate`  
**Location**: `modules/ecs/main.tf` - `aws_security_group.ecs_tasks_sg`

The security group name `${var.project_name}-ecs-task-sg` was static, causing conflicts when the security group already existed from a previous Terraform run.

### Solution
Added a `random_id` resource to generate a unique suffix for the security group name.

### Code Changes

**File**: `modules/ecs/main.tf`

```hcl
# Random ID for unique security group naming
resource "random_id" "sg_suffix" {
  byte_length = 4
  
  keepers = {
    vpc_id = var.vpc_id
  }
}

# 3. Security Group for ECS Tasks
# Using random_id suffix to prevent duplicate security group errors
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${var.project_name}-ecs-task-sg-${random_id.sg_suffix.hex}"
  description = "Allows inbound traffic only from the ALB security group"
  vpc_id      = var.vpc_id
  
  # ... rest of the configuration
}
```

### How It Works
- `random_id.sg_suffix` generates an 8-character hex string (4 bytes)
- The `keepers` block ensures the ID regenerates only when the VPC changes
- Security group name becomes: `venturemond-infra-ecs-task-sg-a1b2c3d4`
- Each apply creates a unique name, preventing conflicts

---

## Fix 2: SES Lambda Permission Missing

### Problem
**Error**: `InvalidLambdaFunction: Could not invoke Lambda function`  
**Location**: `modules/ses_config/main.tf` - `aws_ses_receipt_rule.forwarding_rule`

The SES receipt rule attempted to invoke the Lambda function, but the Lambda function lacked permission to be invoked by `ses.amazonaws.com`.

### Solution
Added `aws_lambda_permission` resource to grant SES invoke permissions, and updated the receipt rule's `depends_on` to ensure the permission is created first.

### Code Changes

**File**: `modules/ses_config/main.tf`

```hcl
# Lambda Permission for SES to invoke the bounce handler
resource "aws_lambda_permission" "allow_ses_invoke" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ses_bounce_handler.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_ses_receipt_rule" "forwarding_rule" {
  for_each      = var.client_domains
  name          = "${each.key}-forward-rule"
  rule_set_name = aws_ses_receipt_rule_set.main_rule_set.rule_set_name
  enabled       = true
  recipients    = [each.value.domain]

  s3_action {
    bucket_name = aws_s3_bucket.ses_inbound_bucket.id
    position    = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.ses_bounce_handler.arn
    position        = 2
    invocation_type = "Event"
  }

  depends_on = [
    aws_s3_bucket_policy.ses_s3_delivery_policy,
    aws_lambda_permission.allow_ses_invoke  # NEW: Ensures permission exists first
  ]
}
```

### How It Works
- `aws_lambda_permission.allow_ses_invoke` creates a resource-based policy on the Lambda function
- Grants `ses.amazonaws.com` permission to invoke the function
- `source_account` restricts invocation to your AWS account only
- `depends_on` ensures the permission is created **before** the SES receipt rule

---

## Fix 3: CloudFront ACM Certificate Timing Error

### Problem
**Error**: `InvalidViewerCertificate`  
**Location**: `modules/static_hosting/main.tf` - `aws_cloudfront_distribution.s3_dist`

Even though the ACM certificate was validated (took 18 minutes), CloudFront couldn't "see" it immediately due to AWS internal propagation delays.

### Solution
Added a `time_sleep` resource to wait 60 seconds after receiving the ACM certificate ARN, ensuring CloudFront can detect the certificate.

### Code Changes

**File**: `modules/static_hosting/main.tf`

```hcl
# 2a. Time Sleep to allow ACM certificate propagation
# CloudFront needs time to detect the certificate after validation
resource "time_sleep" "wait_for_acm_propagation" {
  create_duration = "60s"
  
  triggers = {
    acm_cert_arn = var.acm_certificate_arn
  }
}

# 3. CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_dist" {
  for_each = var.static_client_configs

  # ... origin and cache configuration ...

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name   = "${var.project_name}-${each.key}-cf"
    Client = each.key
  }
  
  depends_on = [time_sleep.wait_for_acm_propagation]  # NEW: Wait for cert propagation
}
```

### How It Works
- `time_sleep.wait_for_acm_propagation` pauses Terraform execution for 60 seconds
- The `triggers` block ensures the timer resets if the certificate ARN changes
- CloudFront distribution creation waits via `depends_on`
- This gives AWS time to propagate the certificate across its internal systems

### Why 60 Seconds?
- ACM certificate validation completes, but CloudFront's global edge network needs time to sync
- 60 seconds is a conservative buffer based on AWS best practices
- You can adjust to 30s if needed, but 60s is safer for production

---

## Verification Steps

After applying these fixes, run:

```bash
# Initialize Terraform (if using new providers like random or time)
terraform init

# Validate the configuration
terraform validate

# Plan to see what will change
terraform plan

# Apply the fixes
terraform apply
```

### Expected Outcomes

1. **ECS Security Group**: Should create with a unique name like `venturemond-infra-ecs-task-sg-a1b2c3d4`
2. **SES Receipt Rule**: Should successfully create without Lambda invocation errors
3. **CloudFront Distribution**: Should create without certificate errors after the 60-second wait

---

## Additional Notes

### Required Terraform Providers

Ensure your `providers.tf` or `versions.tf` includes:

```hcl
terraform {
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
}
```

If you don't have `random` or `time` providers, run:

```bash
terraform init -upgrade
```

---

## Rollback Instructions

If you need to revert these changes:

1. **ECS Security Group**: Remove the `random_id` resource and revert the name to static
2. **SES Lambda Permission**: Remove the `aws_lambda_permission.allow_ses_invoke` resource
3. **CloudFront Timer**: Remove the `time_sleep` resource and the `depends_on` reference

---

## Contact

For questions or issues, contact the infrastructure team.

**Last Updated**: 2026-02-08  
**Author**: Terraform Infrastructure Team
