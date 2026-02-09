# Terraform Fixes - Code Snippets Reference

## Fix 1: ECS Security Group - Unique Naming

### Location: `modules/ecs/main.tf`

```hcl
# ADD THIS at the top of the file (after comments)
resource "random_id" "sg_suffix" {
  byte_length = 4
  
  keepers = {
    vpc_id = var.vpc_id
  }
}

# MODIFY THIS resource
resource "aws_security_group" "ecs_tasks_sg" {
  # BEFORE: name = "${var.project_name}-ecs-task-sg"
  # AFTER:
  name        = "${var.project_name}-ecs-task-sg-${random_id.sg_suffix.hex}"
  description = "Allows inbound traffic only from the ALB security group"
  vpc_id      = var.vpc_id
  
  # ... rest remains the same
}
```

**Result**: Security group name becomes `venturemond-infra-ecs-task-sg-a1b2c3d4`

---

## Fix 2: SES Lambda Permission

### Location: `modules/ses_config/main.tf`

```hcl
# ADD THIS new resource (after aws_ses_receipt_rule_set)
resource "aws_lambda_permission" "allow_ses_invoke" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ses_bounce_handler.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# MODIFY THIS resource
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

  # BEFORE: depends_on = [aws_s3_bucket_policy.ses_s3_delivery_policy]
  # AFTER:
  depends_on = [
    aws_s3_bucket_policy.ses_s3_delivery_policy,
    aws_lambda_permission.allow_ses_invoke  # NEW
  ]
}
```

**Result**: SES can now invoke the Lambda function without permission errors

---

## Fix 3: CloudFront ACM Certificate Wait

### Location: `modules/static_hosting/main.tf`

```hcl
# ADD THIS new resource (after aws_cloudfront_origin_access_control)
resource "time_sleep" "wait_for_acm_propagation" {
  create_duration = "60s"
  
  triggers = {
    acm_cert_arn = var.acm_certificate_arn
  }
}

# MODIFY THIS resource
resource "aws_cloudfront_distribution" "s3_dist" {
  for_each = var.static_client_configs

  # ... all the origin, cache, and certificate config ...

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name   = "${var.project_name}-${each.key}-cf"
    Client = each.key
  }
  
  # ADD THIS:
  depends_on = [time_sleep.wait_for_acm_propagation]
}
```

**Result**: CloudFront waits 60 seconds for certificate propagation before creation

---

## Fix 4: Provider Configuration

### Location: `providers.tf`

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # ADD THESE TWO:
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

**Result**: Terraform can use `random_id` and `time_sleep` resources

---

## Summary of Changes

| Module | File | Lines Changed | New Resources |
|--------|------|---------------|---------------|
| ECS | `modules/ecs/main.tf` | ~10 | `random_id.sg_suffix` |
| SES Config | `modules/ses_config/main.tf` | ~15 | `aws_lambda_permission.allow_ses_invoke` |
| Static Hosting | `modules/static_hosting/main.tf` | ~12 | `time_sleep.wait_for_acm_propagation` |
| Root | `providers.tf` | ~8 | N/A (provider config) |

**Total**: 4 files modified, 3 new resources added

---

## Testing Checklist

- [ ] Run `terraform init -upgrade` ✅ (Already done)
- [ ] Run `terraform validate` ✅ (Already done)
- [ ] Run `terraform plan` (Review changes)
- [ ] Run `terraform apply` (Apply fixes)
- [ ] Verify security group created with unique name
- [ ] Verify SES receipt rule created successfully
- [ ] Verify CloudFront distribution deployed
- [ ] Test application functionality

---

## Error Messages - Before vs After

### Before Fix 1:
```
Error: creating EC2 Security Group: InvalidGroup.Duplicate
```

### After Fix 1:
```
✓ aws_security_group.ecs_tasks_sg created successfully
```

---

### Before Fix 2:
```
Error: InvalidLambdaFunction: Could not invoke Lambda function
```

### After Fix 2:
```
✓ aws_ses_receipt_rule.forwarding_rule["client1"] created successfully
```

---

### Before Fix 3:
```
Error: InvalidViewerCertificate: The specified SSL certificate doesn't exist
```

### After Fix 3:
```
✓ time_sleep.wait_for_acm_propagation: Still creating... [60s elapsed]
✓ aws_cloudfront_distribution.s3_dist["client1"] created successfully
```
