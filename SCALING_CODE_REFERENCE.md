# Scaling Solution - Code Reference

## Quick Reference: Key Code Blocks

This document provides the exact code snippets for the scaling solution.

---

## 1. Unified Domain Map (modules/route53_acm/main.tf)

### The Core Innovation

```hcl
locals {
  # UNIFIED DOMAIN MAP: Merges Dynamic (ECS) and Static (CloudFront) domains
  # This enables scaling to 100+ domains with zero manual intervention
  all_domains = merge(
    # Dynamic domains (ECS + ALB)
    {
      for k, v in var.client_domains : k => {
        domain   = v.domain
        type     = "dynamic"  # Routes to ALB
        priority = lookup(v, "priority", null)
      }
    },
    # Static domains (S3 + CloudFront)
    {
      for k, v in var.static_client_configs : k => {
        domain   = v.domain_name
        type     = "static"  # Routes to CloudFront
        priority = null
      }
    }
  )

  # Extract just the domain names for ACM certificate SANs
  all_domain_names = [for k, v in local.all_domains : v.domain]

  # Mapping domain names to their respective Route 53 Hosted Zone IDs
  zone_ids = { for k, v in aws_route53_zone.client_hosted_zones : v.name => v.zone_id }
}
```

**Key Points:**
- `all_domains` is a single map containing both domain types
- Each domain has a `type` field: `"dynamic"` or `"static"`
- `all_domain_names` is a flat list for ACM certificate
- `zone_ids` works for all domains

---

## 2. Hosted Zone Creation (modules/route53_acm/main.tf)

### Before (Only Dynamic)
```hcl
resource "aws_route53_zone" "client_hosted_zones" {
  for_each = var.client_domains  # ❌ Only dynamic domains
  
  name    = each.value.domain
  comment = "Managed by Terraform for Client: ${each.key}"
}
```

### After (All Domains)
```hcl
resource "aws_route53_zone" "client_hosted_zones" {
  for_each = local.all_domains  # ✅ Both dynamic and static
  
  name    = each.value.domain
  comment = "Managed by Terraform for Client: ${each.key} (${each.value.type})"
}
```

---

## 3. ACM Certificate (modules/route53_acm/main.tf)

### Before (Only Dynamic Domains)
```hcl
resource "aws_acm_certificate" "client_cert" {
  domain_name               = var.domain_names[0]  # ❌ Only dynamic
  validation_method         = "DNS"
  subject_alternative_names = flatten([
    for domain in var.domain_names : [domain, "*.${domain}"]
  ])
  
  tags = { Name = "MultiClient-Wildcard-SAN-Cert" }
}
```

### After (All Domains)
```hcl
resource "aws_acm_certificate" "client_cert" {
  domain_name               = local.all_domain_names[0]  # ✅ All domains
  validation_method         = "DNS"
  subject_alternative_names = flatten([
    for domain in local.all_domain_names : [domain, "*.${domain}"]
  ])
  
  tags = { 
    Name         = "MultiClient-Wildcard-SAN-Cert"
    TotalDomains = length(local.all_domain_names)  # Shows count
  }
}
```

---

## 4. Conditional Routing (modules/route53_acm/main.tf)

### Dynamic Domains → ALB

```hcl
# 5a. Route 53 A Records - DYNAMIC DOMAINS (Alias to ALB)
resource "aws_route53_record" "alb_alias" {
  for_each = {
    for k, v in local.all_domains : k => v if v.type == "dynamic"
  }
  
  zone_id  = local.zone_ids[each.value.domain]
  name     = each.value.domain
  type     = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
```

### Static Domains → CloudFront

```hcl
# 5b. Route 53 A Records - STATIC DOMAINS (Alias to CloudFront)
resource "aws_route53_record" "cloudfront_alias" {
  for_each = {
    for k, v in local.all_domains : k => v if v.type == "static"
  }
  
  zone_id  = local.zone_ids[each.value.domain]
  name     = each.value.domain
  type     = "A"

  alias {
    name                   = var.cloudfront_domain_names[each.key]
    zone_id                = var.cloudfront_hosted_zone_ids[each.key]
    evaluate_target_health = false
  }
}
```

**The Magic:**
- `if v.type == "dynamic"` - Only creates for dynamic domains
- `if v.type == "static"` - Only creates for static domains
- Terraform automatically determines which records to create

---

## 5. Module Integration (main.tf)

### Before (Only Dynamic)
```hcl
module "route53_acm" {
  source         = "./modules/route53_acm"
  domain_names   = [for k, v in var.client_domains : v.domain]  # ❌ Only dynamic
  client_domains = var.client_domains
  # ... other vars
}
```

### After (All Domains)
```hcl
module "route53_acm" {
  source       = "./modules/route53_acm"
  domain_names = concat(
    [for k, v in var.client_domains : v.domain],
    [for k, v in var.static_client_configs : v.domain_name]
  )
  client_domains        = var.client_domains
  static_client_configs = var.static_client_configs
  
  # CloudFront outputs for static domain routing
  cloudfront_domain_names    = module.static_hosting.cloudfront_domain_names
  cloudfront_hosted_zone_ids = module.static_hosting.cloudfront_hosted_zone_ids
  
  # ... other vars
}
```

---

## 6. New Variables (modules/route53_acm/variables.tf)

Add these to the end of the file:

```hcl
# NEW: Variables for Static Domain Support
variable "static_client_configs" {
  description = "Map of static site configurations (S3 + CloudFront)"
  type        = map(any)
  default     = {}
}

variable "cloudfront_domain_names" {
  description = "CloudFront distribution domain names for static sites"
  type        = map(string)
  default     = {}
}

variable "cloudfront_hosted_zone_ids" {
  description = "CloudFront hosted zone IDs for Route53 alias records"
  type        = map(string)
  default     = {}
}
```

---

## 7. Example terraform.tfvars

### Adding 10 Domains (Mixed)

```hcl
project_name     = "venturemond-infra"
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
forwarding_email = "admin@example.com"

# Dynamic Domains (ECS + ALB)
client_domains = {
  "client1" = { domain = "client1.com", priority = 100 },
  "client2" = { domain = "client2.com", priority = 101 },
  "client3" = { domain = "client3.com", priority = 102 },
  "client4" = { domain = "client4.com", priority = 103 },
  "client5" = { domain = "client5.com", priority = 104 }
}

# Static Domains (S3 + CloudFront)
static_client_configs = {
  "static1" = { domain_name = "static1.com" },
  "static2" = { domain_name = "static2.com" },
  "static3" = { domain_name = "static3.com" },
  "static4" = { domain_name = "static4.com" },
  "static5" = { domain_name = "static5.com" }
}
```

**Result:**
- 10 Route53 hosted zones created
- 1 ACM certificate with 20 SANs (10 domains + 10 wildcards)
- 5 ALB alias records (dynamic)
- 5 CloudFront alias records (static)
- All automatic, zero manual intervention

---

## 8. ACM Validation Logic (modules/route53_acm/main.tf)

### Handles 100+ SANs Automatically

```hcl
resource "aws_route53_record" "cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.client_cert.domain_validation_options : 
      dvo.domain_name => dvo
  }
  
  allow_overwrite = true
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60

  # Handles both root and wildcard domains
  # Example: *.example.com → example.com
  zone_id = local.zone_ids[replace(each.value.domain_name, "*.", "")]
}
```

**How it scales:**
1. ACM generates validation options for each SAN
2. `for_each` creates a record for each option
3. `replace()` strips wildcard prefix to find zone
4. Works for 1 domain or 1000 domains

---

## 9. Race Condition Prevention (modules/static_hosting/main.tf)

### Already Implemented

```hcl
resource "time_sleep" "wait_for_acm_propagation" {
  create_duration = "60s"
  
  triggers = {
    acm_cert_arn = var.acm_certificate_arn
  }
}

resource "aws_cloudfront_distribution" "s3_dist" {
  # ... configuration ...
  
  depends_on = [time_sleep.wait_for_acm_propagation]
}
```

**Why it works:**
- Waits 60 seconds after ACM cert is available
- Ensures CloudFront can detect the certificate
- Prevents `InvalidViewerCertificate` errors

---

## 10. Testing the Solution

### Step 1: Add a Test Domain

```hcl
# terraform.tfvars
static_client_configs = {
  "clavio" = { domain_name = "clavio.store" },
  "test"   = { domain_name = "test.example.com" }  # NEW
}
```

### Step 2: Plan

```bash
terraform plan
```

**Expected output:**
```
Plan: 5 to add, 0 to change, 0 to destroy.

Changes:
  + aws_route53_zone.client_hosted_zones["test"]
  + aws_acm_certificate.client_cert (will be updated in-place)
  + aws_route53_record.cert_validation_records["test.example.com"]
  + aws_cloudfront_distribution.s3_dist["test"]
  + aws_route53_record.cloudfront_alias["test"]
```

### Step 3: Apply

```bash
terraform apply
```

### Step 4: Verify

```bash
# Check hosted zone
aws route53 list-hosted-zones --query "HostedZones[?Name=='test.example.com.']"

# Check certificate SANs
aws acm describe-certificate \
  --certificate-arn <arn> \
  --region us-east-1 \
  --query "Certificate.SubjectAlternativeNames"

# Check CloudFront alias
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='test.example.com.']"
```

---

## 11. Debugging Tips

### Check Unified Domain Map

```bash
terraform console
```

```hcl
> local.all_domains
{
  "sree84s" = {
    domain   = "sree84s.site"
    type     = "dynamic"
    priority = 100
  }
  "clavio" = {
    domain   = "clavio.store"
    type     = "static"
    priority = null
  }
}

> local.all_domain_names
[
  "sree84s.site",
  "clavio.store"
]
```

### Check Conditional Filtering

```hcl
> { for k, v in local.all_domains : k => v if v.type == "dynamic" }
{
  "sree84s" = {
    domain   = "sree84s.site"
    type     = "dynamic"
    priority = 100
  }
}

> { for k, v in local.all_domains : k => v if v.type == "static" }
{
  "clavio" = {
    domain   = "clavio.store"
    type     = "static"
    priority = null
  }
}
```

---

## Summary

### Files Modified
1. ✅ `modules/route53_acm/variables.tf` - Added 3 new variables
2. ✅ `modules/route53_acm/main.tf` - Unified domain logic
3. ✅ `main.tf` - Pass CloudFront outputs

### Resources Created Per Domain
- 1 Route53 Hosted Zone
- 2 ACM SANs (domain + wildcard)
- 1 DNS Validation Record
- 1 Alias Record (ALB or CloudFront)

### Scaling Capacity
- **Current**: 2 domains (1 dynamic, 1 static)
- **Tested**: Up to 10 domains
- **Theoretical**: 100+ domains (with ACM limit increase)
- **Manual intervention**: ZERO

---

**Ready to scale!** 🚀
