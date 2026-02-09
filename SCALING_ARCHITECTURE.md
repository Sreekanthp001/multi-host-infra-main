# Terraform Scaling Solution for 100+ Domains

## Overview
This document explains the **zero-touch scaling architecture** that enables your multi-tenant infrastructure to automatically handle 100+ domains (both Dynamic ECS-based and Static S3/CloudFront-based) by simply adding entries to `terraform.tfvars`.

---

## 🎯 Key Features

✅ **Unified Domain Management**: Single source of truth merges dynamic and static domains  
✅ **Automatic Route53 Hosted Zones**: Created for all domains automatically  
✅ **Single ACM Certificate**: All 100+ domains included as SANs with wildcards  
✅ **Conditional Routing**: ALB for dynamic, CloudFront for static - automatically determined  
✅ **Robust ACM Validation**: Handles 100+ SANs with proper zone mapping  
✅ **Race Condition Prevention**: Built-in delays for certificate propagation  

---

## 🏗️ Architecture Changes

### 1. Unified Domain Map (route53_acm/main.tf)

The core innovation is the `all_domains` local that merges both domain types:

```hcl
locals {
  # UNIFIED DOMAIN MAP: Merges Dynamic (ECS) and Static (CloudFront) domains
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

  # Extract just domain names for ACM certificate SANs
  all_domain_names = [for k, v in local.all_domains : v.domain]

  # Zone ID mapping works for ALL domains
  zone_ids = { for k, v in aws_route53_zone.client_hosted_zones : v.name => v.zone_id }
}
```

**How it works:**
- Merges `client_domains` (dynamic) and `static_client_configs` (static)
- Each domain gets a `type` field: `"dynamic"` or `"static"`
- `all_domain_names` list is used for ACM certificate SANs
- Single `zone_ids` map works for all domains

---

### 2. Automatic Hosted Zone Creation

**Before:** Only created for `client_domains`  
**After:** Created for ALL domains

```hcl
resource "aws_route53_zone" "client_hosted_zones" {
  for_each = local.all_domains  # ← Now includes both types

  name    = each.value.domain
  comment = "Managed by Terraform for Client: ${each.key} (${each.value.type})"
}
```

**Scaling behavior:**
- Add domain to `terraform.tfvars` → Hosted zone automatically created
- Works for 1 domain or 100+ domains
- No code changes needed

---

### 3. Single ACM Certificate for All Domains

**Before:** Only included `var.domain_names` (dynamic only)  
**After:** Includes ALL domains with wildcards

```hcl
resource "aws_acm_certificate" "client_cert" {
  domain_name               = local.all_domain_names[0]
  validation_method         = "DNS"
  subject_alternative_names = flatten([
    for domain in local.all_domain_names : [domain, "*.${domain}"]
  ])

  tags = { 
    Name         = "MultiClient-Wildcard-SAN-Cert"
    TotalDomains = length(local.all_domain_names)  # ← Shows count
  }
}
```

**Scaling behavior:**
- Single certificate for all domains (100+)
- Each domain gets: `example.com` + `*.example.com`
- AWS ACM limit: 100 SANs per certificate (you can request increase to 1000+)

---

### 4. Robust ACM Validation for 100+ SANs

**Challenge:** ACM creates validation records for each SAN, including wildcards  
**Solution:** Automatic zone mapping handles all cases

```hcl
resource "aws_route53_record" "cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.client_cert.domain_validation_options : dvo.domain_name => dvo
  }
  
  allow_overwrite = true
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60

  # Handles both root and wildcard domains
  zone_id = local.zone_ids[replace(each.value.domain_name, "*.", "")]
}
```

**How it handles 100+ domains:**
1. ACM generates validation options for each domain + wildcard
2. `for_each` creates a record for each validation option
3. `replace()` strips `*.` from wildcards to find the correct zone
4. Works for any number of domains

---

### 5. Conditional Routing - The Magic

**Before:** Only ALB alias records  
**After:** Automatic routing based on domain type

#### 5a. Dynamic Domains → ALB

```hcl
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

#### 5b. Static Domains → CloudFront

```hcl
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

**How it works:**
- `if v.type == "dynamic"` filters only dynamic domains
- `if v.type == "static"` filters only static domains
- Terraform automatically creates the right record type
- Zero manual intervention required

---

### 6. Race Condition Prevention

**Problem:** CloudFront can't find ACM certificate immediately after validation  
**Solution:** 60-second wait timer

```hcl
resource "time_sleep" "wait_for_acm_propagation" {
  create_duration = "60s"
  
  triggers = {
    acm_cert_arn = var.acm_certificate_arn
  }
}

resource "aws_cloudfront_distribution" "s3_dist" {
  # ... config ...
  
  depends_on = [time_sleep.wait_for_acm_propagation]
}
```

**Why this works:**
- ACM certificate validation completes in Route53
- AWS needs time to propagate cert to CloudFront edge locations
- 60s delay ensures CloudFront can "see" the certificate
- Prevents `InvalidViewerCertificate` errors

---

## 📝 How to Add New Domains

### Adding a Dynamic Domain (ECS + ALB)

Edit `terraform.tfvars`:

```hcl
client_domains = {
  "sree84s" = {
    domain   = "sree84s.site"
    priority = 100
  },
  # ADD NEW DOMAIN HERE
  "newclient" = {
    domain   = "newclient.com"
    priority = 101
  }
}
```

**What happens automatically:**
1. ✅ Route53 hosted zone created for `newclient.com`
2. ✅ Domain added to ACM certificate SANs
3. ✅ DNS validation record created
4. ✅ ALB alias record created (routes to ALB)
5. ✅ SES records created (MX, SPF, DKIM, DMARC)
6. ✅ ECS service created with ALB listener rule

### Adding a Static Domain (S3 + CloudFront)

Edit `terraform.tfvars`:

```hcl
static_client_configs = {
  "clavio" = { domain_name = "clavio.store" },
  # ADD NEW DOMAIN HERE
  "newstatic" = { domain_name = "newstatic.io" }
}
```

**What happens automatically:**
1. ✅ Route53 hosted zone created for `newstatic.io`
2. ✅ Domain added to ACM certificate SANs
3. ✅ DNS validation record created
4. ✅ S3 bucket created
5. ✅ CloudFront distribution created
6. ✅ CloudFront alias record created (routes to CloudFront)

---

## 🔄 Terraform Apply Flow

```
terraform apply
    │
    ├─► Create Route53 Hosted Zones (all domains)
    │   └─► local.all_domains (dynamic + static)
    │
    ├─► Create ACM Certificate (all domains as SANs)
    │   └─► local.all_domain_names
    │
    ├─► Create DNS Validation Records
    │   └─► One per domain + wildcard
    │
    ├─► Wait for ACM Validation (~5-10 mins)
    │
    ├─► Create ALB (if dynamic domains exist)
    │
    ├─► Create CloudFront Distributions (if static domains exist)
    │   └─► Wait 60s for ACM propagation
    │
    ├─► Create ALB Alias Records
    │   └─► Only for type = "dynamic"
    │
    └─► Create CloudFront Alias Records
        └─► Only for type = "static"
```

---

## 📊 Scaling Limits

| Resource | AWS Limit | Current Design | Notes |
|----------|-----------|----------------|-------|
| ACM SANs per cert | 100 (default) | Unlimited* | Request increase to 1000+ |
| Route53 zones | 500 per account | Unlimited | Soft limit, can increase |
| CloudFront distributions | 200 per account | Unlimited | Soft limit, can increase |
| ALB listener rules | 100 per listener | Limited by priority | Use multiple ALBs if needed |

*For 100+ domains, request ACM SAN limit increase via AWS Support

---

## 🛠️ Troubleshooting

### Issue: ACM Certificate Validation Fails

**Symptom:** Validation stuck for 20+ minutes

**Solution:**
1. Check DNS records are created in correct hosted zones
2. Verify nameservers are correctly delegated
3. Check for duplicate validation records

```bash
# Check validation records
aws route53 list-resource-record-sets --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

### Issue: CloudFront Can't Find Certificate

**Symptom:** `InvalidViewerCertificate` error

**Solution:**
1. Verify certificate is in `us-east-1` region
2. Increase `time_sleep` duration to 120s
3. Check certificate status:

```bash
aws acm describe-certificate \
  --certificate-arn <arn> \
  --region us-east-1
```

### Issue: Wrong Alias Record Created

**Symptom:** Static domain points to ALB or vice versa

**Solution:**
1. Check domain type in `all_domains` local
2. Verify `domain` vs `domain_name` field usage
3. Run `terraform plan` to see which resources will be created

---

## 🎯 Best Practices

### 1. Domain Naming Convention
```hcl
client_domains = {
  "client1-prod" = { domain = "client1.com", priority = 100 },
  "client1-dev"  = { domain = "dev.client1.com", priority = 101 }
}
```

### 2. Priority Management
- Start at 100, increment by 1
- Reserve 1-99 for system/default rules
- Use priority ranges: 100-199 (prod), 200-299 (staging), etc.

### 3. Monitoring
```hcl
# Add CloudWatch alarms for certificate expiry
resource "aws_cloudwatch_metric_alarm" "cert_expiry" {
  alarm_name          = "acm-cert-expiry"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400"
  statistic           = "Minimum"
  threshold           = "30"
}
```

### 4. State Management
- Use S3 backend for state storage
- Enable state locking with DynamoDB
- Regular state backups

---

## 📚 Files Modified

| File | Purpose | Key Changes |
|------|---------|-------------|
| `modules/route53_acm/variables.tf` | Add static domain support | Added 3 new variables |
| `modules/route53_acm/main.tf` | Unified domain logic | New locals, conditional routing |
| `main.tf` | Module integration | Pass CloudFront outputs |
| `modules/static_hosting/main.tf` | Race condition fix | Already has time_sleep |

---

## 🚀 Next Steps

1. **Test with 10 domains** - Verify the logic works
2. **Request ACM limit increase** - If planning 100+ domains
3. **Set up monitoring** - CloudWatch alarms for cert expiry
4. **Document nameserver delegation** - For clients to update DNS
5. **Automate domain addition** - CI/CD pipeline to update tfvars

---

## 📞 Support

For issues or questions:
1. Check `terraform plan` output before applying
2. Review CloudWatch logs for errors
3. Use `terraform state list` to verify resources
4. Contact infrastructure team for assistance

**Last Updated:** 2026-02-08  
**Version:** 2.0 - Unified Scaling Architecture
