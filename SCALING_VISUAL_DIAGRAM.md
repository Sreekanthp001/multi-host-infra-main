# Scaling Architecture - Visual Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     TERRAFORM SCALING ARCHITECTURE                              │
│                   Zero-Touch Scaling for 100+ Domains                           │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                          INPUT: terraform.tfvars                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   client_domains = {                    static_client_configs = {              │
│     "client1" = {                         "static1" = {                         │
│       domain   = "client1.com"              domain_name = "static1.com"        │
│       priority = 100                      }                                     │
│     }                                     "static2" = {                         │
│     "client2" = {                           domain_name = "static2.com"        │
│       domain   = "client2.com"            }                                     │
│       priority = 101                    }                                       │
│     }                                                                           │
│   }                                                                             │
│                                                                                 │
│   ┌─────────────────────┐                ┌─────────────────────┐               │
│   │  Dynamic Domains    │                │  Static Domains     │               │
│   │  (ECS + ALB)        │                │  (S3 + CloudFront)  │               │
│   └─────────────────────┘                └─────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    PROCESSING: modules/route53_acm/main.tf                      │
│                              Unified Domain Map                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   locals {                                                                      │
│     all_domains = merge(                                                        │
│       {                                                                         │
│         "client1" => { domain = "client1.com", type = "dynamic" }               │
│         "client2" => { domain = "client2.com", type = "dynamic" }               │
│       },                                                                        │
│       {                                                                         │
│         "static1" => { domain = "static1.com", type = "static" }                │
│         "static2" => { domain = "static2.com", type = "static" }                │
│       }                                                                         │
│     )                                                                           │
│                                                                                 │
│     all_domain_names = [                                                        │
│       "client1.com", "client2.com", "static1.com", "static2.com"                │
│     ]                                                                           │
│   }                                                                             │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────┐               │
│   │  UNIFIED MAP: 4 domains, 2 types, single source of truth   │               │
│   └─────────────────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        STEP 1: Route53 Hosted Zones                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   resource "aws_route53_zone" "client_hosted_zones" {                          │
│     for_each = local.all_domains  ← ALL 4 DOMAINS                              │
│   }                                                                             │
│                                                                                 │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐               │
│   │ client1.com     │  │ client2.com     │  │ static1.com     │               │
│   │ Zone ID: Z1234  │  │ Zone ID: Z2345  │  │ Zone ID: Z3456  │               │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘               │
│                                                                                 │
│   ┌─────────────────┐                                                          │
│   │ static2.com     │                                                          │
│   │ Zone ID: Z4567  │                                                          │
│   └─────────────────┘                                                          │
│                                                                                 │
│   ✅ 4 Hosted Zones Created Automatically                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      STEP 2: ACM Certificate (us-east-1)                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   resource "aws_acm_certificate" "client_cert" {                               │
│     domain_name = "client1.com"                                                │
│     subject_alternative_names = [                                              │
│       "client1.com", "*.client1.com",  ← Wildcard                              │
│       "client2.com", "*.client2.com",                                          │
│       "static1.com", "*.static1.com",                                          │
│       "static2.com", "*.static2.com"                                           │
│     ]                                                                           │
│   }                                                                             │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────┐               │
│   │  Single Certificate: 8 SANs (4 domains + 4 wildcards)      │               │
│   │  ARN: arn:aws:acm:us-east-1:xxx:certificate/xxx            │               │
│   └─────────────────────────────────────────────────────────────┘               │
│                                                                                 │
│   ✅ 1 Certificate for ALL Domains                                             │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      STEP 3: DNS Validation Records                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   resource "aws_route53_record" "cert_validation_records" {                    │
│     for_each = domain_validation_options  ← 8 validation records               │
│                                                                                 │
│     zone_id = local.zone_ids[                                                  │
│       replace(each.value.domain_name, "*.", "")  ← Handles wildcards           │
│     ]                                                                           │
│   }                                                                             │
│                                                                                 │
│   ┌──────────────────────────────────────────────────────────────┐              │
│   │  _abc123.client1.com  CNAME  _xyz789.acm-validations.aws    │              │
│   │  _abc123.client2.com  CNAME  _xyz789.acm-validations.aws    │              │
│   │  _abc123.static1.com  CNAME  _xyz789.acm-validations.aws    │              │
│   │  _abc123.static2.com  CNAME  _xyz789.acm-validations.aws    │              │
│   └──────────────────────────────────────────────────────────────┘              │
│                                                                                 │
│   ⏱️  Validation Time: 5-10 minutes                                            │
│   ✅ 8 Validation Records Created (4 domains + 4 wildcards)                    │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    STEP 4: Conditional Routing - THE MAGIC                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐           │
│   │  for k, v in local.all_domains : k => v if v.type == "dynamic"  │           │
│   └─────────────────────────────────────────────────────────────────┘           │
│                         │                                                       │
│                         ▼                                                       │
│   ┌─────────────────────────────────────────────────────────────────┐           │
│   │  DYNAMIC DOMAINS → ALB Alias Records                            │           │
│   ├─────────────────────────────────────────────────────────────────┤           │
│   │                                                                 │           │
│   │  client1.com  A  ALIAS  → alb-xxx.us-east-1.elb.amazonaws.com  │           │
│   │  client2.com  A  ALIAS  → alb-xxx.us-east-1.elb.amazonaws.com  │           │
│   │                                                                 │           │
│   │  ┌──────────┐                                                  │           │
│   │  │   ALB    │ ← Routes traffic to ECS tasks                    │           │
│   │  └──────────┘                                                  │           │
│   └─────────────────────────────────────────────────────────────────┘           │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐           │
│   │  for k, v in local.all_domains : k => v if v.type == "static"   │           │
│   └─────────────────────────────────────────────────────────────────┘           │
│                         │                                                       │
│                         ▼                                                       │
│   ┌─────────────────────────────────────────────────────────────────┐           │
│   │  STATIC DOMAINS → CloudFront Alias Records                      │           │
│   ├─────────────────────────────────────────────────────────────────┤           │
│   │                                                                 │           │
│   │  static1.com  A  ALIAS  → d111111abcdef8.cloudfront.net        │           │
│   │  static2.com  A  ALIAS  → d222222abcdef8.cloudfront.net        │           │
│   │                                                                 │           │
│   │  ┌──────────────┐                                              │           │
│   │  │  CloudFront  │ ← Routes traffic to S3 buckets               │           │
│   │  └──────────────┘                                              │           │
│   └─────────────────────────────────────────────────────────────────┘           │
│                                                                                 │
│   ✅ 2 ALB Alias Records (dynamic)                                             │
│   ✅ 2 CloudFront Alias Records (static)                                       │
│   ✅ ZERO Manual Configuration                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         STEP 5: Race Condition Prevention                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   resource "time_sleep" "wait_for_acm_propagation" {                           │
│     create_duration = "60s"                                                    │
│   }                                                                             │
│                                                                                 │
│   resource "aws_cloudfront_distribution" "s3_dist" {                           │
│     depends_on = [time_sleep.wait_for_acm_propagation]                         │
│   }                                                                             │
│                                                                                 │
│   ┌────────────────────────────────────────────────────────────┐                │
│   │  ACM Cert Validated → Wait 60s → CloudFront Created       │                │
│   └────────────────────────────────────────────────────────────┘                │
│                                                                                 │
│   ✅ Prevents InvalidViewerCertificate Errors                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              FINAL RESULT                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Internet                                                                      │
│      │                                                                          │
│      ├──► client1.com ──► Route53 ──► ALB ──► ECS Tasks                        │
│      │                                                                          │
│      ├──► client2.com ──► Route53 ──► ALB ──► ECS Tasks                        │
│      │                                                                          │
│      ├──► static1.com ──► Route53 ──► CloudFront ──► S3 Bucket                 │
│      │                                                                          │
│      └──► static2.com ──► Route53 ──► CloudFront ──► S3 Bucket                 │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────┐               │
│   │  All domains use the SAME ACM certificate                   │               │
│   │  All traffic is HTTPS (TLS 1.2+)                            │               │
│   │  Routing is AUTOMATIC based on domain type                  │               │
│   └─────────────────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         SCALING TO 100+ DOMAINS                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   terraform.tfvars                                                              │
│   ┌─────────────────────────────────────────────────────────────┐               │
│   │  client_domains = {                                         │               │
│   │    "client1"  = { domain = "client1.com",  priority = 100 } │               │
│   │    "client2"  = { domain = "client2.com",  priority = 101 } │               │
│   │    "client3"  = { domain = "client3.com",  priority = 102 } │               │
│   │    ...                                                      │               │
│   │    "client50" = { domain = "client50.com", priority = 149 } │               │
│   │  }                                                          │               │
│   │                                                             │               │
│   │  static_client_configs = {                                 │               │
│   │    "static1"  = { domain_name = "static1.com"  }           │               │
│   │    "static2"  = { domain_name = "static2.com"  }           │               │
│   │    ...                                                      │               │
│   │    "static50" = { domain_name = "static50.com" }           │               │
│   │  }                                                          │               │
│   └─────────────────────────────────────────────────────────────┘               │
│                                                                                 │
│   terraform apply                                                               │
│   ┌─────────────────────────────────────────────────────────────┐               │
│   │  ✅ 100 Route53 Hosted Zones                                │               │
│   │  ✅ 1 ACM Certificate (200 SANs)                            │               │
│   │  ✅ 200 DNS Validation Records                              │               │
│   │  ✅ 50 ALB Alias Records                                    │               │
│   │  ✅ 50 CloudFront Alias Records                             │               │
│   │  ✅ 50 CloudFront Distributions                             │               │
│   │  ✅ 50 S3 Buckets                                           │               │
│   │                                                             │               │
│   │  TOTAL: 600+ resources created AUTOMATICALLY               │               │
│   │  MANUAL STEPS: ZERO                                        │               │
│   └─────────────────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                            KEY INNOVATIONS                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  1️⃣  UNIFIED DOMAIN MAP                                                        │
│     • Merges dynamic and static domains into single data structure             │
│     • Each domain tagged with type: "dynamic" or "static"                      │
│     • Single source of truth for all domain operations                         │
│                                                                                 │
│  2️⃣  CONDITIONAL RESOURCE CREATION                                             │
│     • if v.type == "dynamic"  → Creates ALB alias                              │
│     • if v.type == "static"   → Creates CloudFront alias                       │
│     • Terraform automatically determines which resources to create             │
│                                                                                 │
│  3️⃣  AUTOMATIC ZONE MAPPING                                                    │
│     • replace(domain, "*.", "") strips wildcards                               │
│     • local.zone_ids[domain] finds correct hosted zone                         │
│     • Works for 1 domain or 1000 domains identically                           │
│                                                                                 │
│  4️⃣  RACE CONDITION PREVENTION                                                 │
│     • time_sleep ensures ACM cert propagates before CloudFront uses it         │
│     • depends_on chains resources in correct order                             │
│     • Prevents intermittent deployment failures                                │
│                                                                                 │
│  5️⃣  ZERO MANUAL INTERVENTION                                                  │
│     • Add domain to tfvars                                                     │
│     • Run terraform apply                                                      │
│     • Everything else is automatic                                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```
