# Client Onboarding Runbook
## Zero-Touch Domain + Email Setup for Venturemond Multi-Tenant Platform

**Version:** 2.0  
**Last Updated:** 2026-02-08  
**Estimated Time:** 25-30 minutes (mostly AWS propagation)  

---

## Overview

This runbook explains how to onboard a new client (domain + email) in **one terraform apply** with zero manual intervention.

**What Gets Created Automatically:**
- ✅ Route53 Hosted Zone
- ✅ ACM SSL Certificate (added as SAN)
- ✅ DNS Validation Records
- ✅ ALB Listener Rule (dynamic) OR CloudFront Distribution (static)
- ✅ Route53 Alias Record (points to ALB or CloudFront)
- ✅ SES Domain Verification
- ✅ SES DKIM, SPF, DMARC, MX Records
- ✅ SES Receipt Rules (inbound email)
- ✅ ECS Service (dynamic only)
- ✅ S3 Bucket (static only)

---

## Prerequisites

Before onboarding a client, ensure:

1. ✅ You have the client's domain name
2. ✅ You know if it's **dynamic** (ECS app) or **static** (S3 website)
3. ✅ You have AWS CLI configured
4. ✅ Terraform is installed and initialized
5. ✅ You have access to the domain registrar (for nameserver delegation)

---

## Onboarding Process

### Step 1: Add Domain to terraform.tfvars

#### For Dynamic Domain (ECS + ALB)

Edit `terraform.tfvars`:

```hcl
client_domains = {
  "sree84s" = {
    domain   = "sree84s.site"
    priority = 100
  },
  
  # ADD NEW CLIENT HERE
  "newclient" = {
    domain   = "newclient.com"
    priority = 101  # Must be unique, increment from last
  }
}
```

**Priority Rules:**
- Must be unique across all clients
- Range: 1-999
- Recommendation: Start at 100, increment by 1
- Used for ALB listener rule ordering

#### For Static Domain (S3 + CloudFront)

Edit `terraform.tfvars`:

```hcl
static_client_configs = {
  "clavio" = {
    domain_name = "clavio.store"
  },
  
  # ADD NEW CLIENT HERE
  "newstatic" = {
    domain_name = "newstatic.io"
  }
}
```

**Note:** Static domains don't need priority (no ALB routing)

---

### Step 2: Preview Changes

```bash
cd c:\devops\git-repo\multi-host-infra
terraform plan
```

**Expected Output:**

```
Plan: 15 to add, 1 to change, 0 to destroy.

Changes to Outputs:
  + all_domain_names = [
      + "sree84s.site",
      + "clavio.store",
      + "newclient.com",  # NEW
    ]
```

**Resources to be created (Dynamic Domain):**

```
+ aws_route53_zone.client_hosted_zones["newclient"]
+ aws_acm_certificate.client_cert (will be updated in-place)
+ aws_route53_record.cert_validation_records["newclient.com"]
+ aws_route53_record.cert_validation_records["*.newclient.com"]
+ aws_route53_record.alb_alias["newclient"]
+ aws_ses_domain_identity.client_ses_identity["newclient"]
+ aws_ses_domain_dkim.client_ses_dkim["newclient"]
+ aws_route53_record.ses_dkim_records["newclient_0"]
+ aws_route53_record.ses_dkim_records["newclient_1"]
+ aws_route53_record.ses_dkim_records["newclient_2"]
+ aws_route53_record.client_mx_record["newclient"]
+ aws_route53_record.client_spf_record["newclient"]
+ aws_route53_record.client_dmarc_record["newclient"]
+ aws_lb_target_group.client_tg["newclient"]
+ aws_lb_listener_rule.host_rule["newclient"]
+ aws_ecs_service.client_service["newclient"]
```

**Total:** ~16 resources for dynamic, ~12 for static

---

### Step 3: Apply Changes

```bash
terraform apply
```

Type `yes` when prompted.

**Timeline:**

```
0:00  ► Terraform starts
0:30  ► Route53 hosted zone created
1:00  ► ACM certificate updated (new SANs added)
1:30  ► DNS validation records created
2:00  ► Waiting for ACM validation...
      ⏱️  (This can take 5-20 minutes)
18:00 ► ACM certificate validated ✓
18:30 ► SES domain identity created
19:00 ► SES DKIM tokens generated
19:30 ► All DNS records created
20:00 ► ALB listener rule created (or CloudFront distribution)
20:30 ► ECS service created (dynamic) or S3 bucket (static)
25:00 ► Terraform apply complete ✓
```

**Total Time:** 20-30 minutes (mostly ACM validation)

---

### Step 4: Get Nameservers

After `terraform apply` completes, get the nameservers:

```bash
# Get the hosted zone ID
terraform output -json | jq -r '.route53_zone_ids.value.newclient'

# Or use AWS CLI
aws route53 get-hosted-zone --id <zone-id> --query "DelegationSet.NameServers" --output table
```

**Example Output:**

```
-----------------------------------------
|          GetHostedZone                |
+---------------------------------------+
|  ns-1234.awsdns-12.org                |
|  ns-5678.awsdns-34.com                |
|  ns-9012.awsdns-56.net                |
|  ns-3456.awsdns-78.co.uk              |
+---------------------------------------+
```

---

### Step 5: Delegate Nameservers at Registrar

**Instructions for common registrars:**

#### GoDaddy
1. Log in to GoDaddy
2. Go to "My Products" → "Domains"
3. Click on the domain → "Manage DNS"
4. Click "Change Nameservers"
5. Select "Custom"
6. Enter the 4 AWS nameservers
7. Save

#### Namecheap
1. Log in to Namecheap
2. Go to "Domain List"
3. Click "Manage" next to the domain
4. Under "Nameservers", select "Custom DNS"
5. Enter the 4 AWS nameservers
6. Save

#### Cloudflare
1. Log in to Cloudflare
2. Add the domain
3. Cloudflare will scan existing DNS records
4. Update nameservers at your registrar to Cloudflare's NS
5. **Note:** If using Cloudflare, you'll need to manually add DNS records

**DNS Propagation Time:** 24-48 hours (usually faster)

---

### Step 6: Verify DNS Resolution

After nameserver delegation (wait 1-2 hours):

```bash
# Check nameservers
dig NS newclient.com

# Check A record (should point to ALB or CloudFront)
dig A newclient.com

# Check MX record (should point to SES)
dig MX newclient.com

# Check DKIM records
dig TXT <dkim-token>._domainkey.newclient.com
```

**Expected Results:**

```bash
# A Record (Dynamic)
newclient.com.  300  IN  A  ALIAS  venturemond-infra-alb-xxx.us-east-1.elb.amazonaws.com

# A Record (Static)
newclient.com.  300  IN  A  ALIAS  d111111abcdef8.cloudfront.net

# MX Record
newclient.com.  300  IN  MX  10 inbound-smtp.us-east-1.amazonaws.com

# SPF Record
newclient.com.  300  IN  TXT  "v=spf1 include:amazonses.com ~all"

# DMARC Record
_dmarc.newclient.com.  300  IN  TXT  "v=DMARC1; p=none; rua=mailto:dmarc-reports@newclient.com"
```

---

### Step 7: Verify SES Domain

Check SES domain verification status:

```bash
aws ses get-identity-verification-attributes \
  --identities newclient.com \
  --region us-east-1
```

**Expected Output:**

```json
{
  "VerificationAttributes": {
    "newclient.com": {
      "VerificationStatus": "Success"
    }
  }
}
```

**If status is "Pending":**
- Wait for DNS propagation (up to 72 hours)
- Verify DKIM records are correct
- Check nameservers are delegated

---

### Step 8: Test Email Sending (Dynamic Domains Only)

#### Send Test Email

```bash
aws ses send-email \
  --from "noreply@newclient.com" \
  --destination "ToAddresses=test@example.com" \
  --message "Subject={Data=Test Email},Body={Text={Data=This is a test email from newclient.com}}" \
  --region us-east-1
```

**If SES is in Sandbox Mode:**
- You can only send to verified email addresses
- Request production access: AWS Console → SES → Account Dashboard → Request Production Access

#### Test Inbound Email

Send an email to `anything@newclient.com`

**Expected Flow:**
1. Email arrives at SES
2. SES stores email in S3 bucket: `venturemond-infra-ses-inbound-storage-2026`
3. SES triggers Lambda function: `venturemond-infra-ses-bounce-complaint-handler`
4. Lambda processes bounce/complaint (if applicable)

**Verify:**

```bash
# Check S3 bucket for received email
aws s3 ls s3://venturemond-infra-ses-inbound-storage-2026/ --recursive

# Check Lambda logs
aws logs tail /aws/lambda/venturemond-infra-ses-bounce-complaint-handler --follow
```

---

### Step 9: Test Application Access

#### For Dynamic Domains (ECS)

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster venturemond-infra-cluster \
  --services venturemond-infra-newclient-svc \
  --region us-east-1 \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}"
```

**Expected:**
```json
{
  "Status": "ACTIVE",
  "Running": 2,
  "Desired": 2
}
```

**Test HTTPS Access:**

```bash
curl -I https://newclient.com
```

**Expected:**
```
HTTP/2 200
server: awselb/2.0
```

#### For Static Domains (S3 + CloudFront)

**Upload test content:**

```bash
echo "<h1>Welcome to newstatic.io</h1>" > index.html

aws s3 cp index.html s3://venturemond-infra-newstatic-static-content/
```

**Test CloudFront Access:**

```bash
curl -I https://newstatic.io
```

**Expected:**
```
HTTP/2 200
server: CloudFront
x-cache: Hit from cloudfront
```

---

### Step 10: Monitor Resources

#### Check CloudWatch Logs

```bash
# ECS container logs (dynamic)
aws logs tail /ecs/venturemond-infra-client-app --follow --filter-pattern "newclient"

# CloudFront access logs (static)
aws s3 ls s3://venturemond-infra-cloudfront-logs/
```

#### Check ALB Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1
```

**Expected:**
```json
{
  "TargetHealthDescriptions": [
    {
      "Target": {
        "Id": "10.0.11.123",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy"
      }
    }
  ]
}
```

---

## Troubleshooting

### Issue 1: ACM Validation Stuck

**Symptom:** Certificate validation takes > 30 minutes

**Diagnosis:**

```bash
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1 \
  --query "Certificate.DomainValidationOptions"
```

**Common Causes:**
1. DNS records not created
2. Nameservers not delegated
3. CNAME record has wrong value

**Fix:**

```bash
# Check DNS records exist
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Type=='CNAME']"

# Verify nameservers
dig NS newclient.com
```

---

### Issue 2: ECS Service Not Starting

**Symptom:** `runningCount` is 0

**Diagnosis:**

```bash
aws ecs describe-services \
  --cluster venturemond-infra-cluster \
  --services venturemond-infra-newclient-svc \
  --region us-east-1 \
  --query "services[0].events[0:5]"
```

**Common Causes:**
1. ECR image not available
2. Task definition has errors
3. Security group blocking traffic
4. Insufficient ENIs in subnet

**Fix:**

```bash
# Check ECR image exists
aws ecr describe-images \
  --repository-name venturemond-infra-repo \
  --region us-east-1

# Check task definition
aws ecs describe-task-definition \
  --task-definition venturemond-infra-task \
  --region us-east-1

# Check stopped tasks
aws ecs list-tasks \
  --cluster venturemond-infra-cluster \
  --desired-status STOPPED \
  --region us-east-1
```

---

### Issue 3: SES Domain Not Verifying

**Symptom:** Verification status stuck at "Pending"

**Diagnosis:**

```bash
aws ses get-identity-verification-attributes \
  --identities newclient.com \
  --region us-east-1
```

**Common Causes:**
1. DKIM records not created
2. MX record missing
3. DNS propagation delay

**Fix:**

```bash
# Check DKIM tokens
aws ses get-identity-dkim-attributes \
  --identities newclient.com \
  --region us-east-1

# Verify DKIM records in Route53
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Type=='CNAME' && contains(Name, '_domainkey')]"

# Wait 24-72 hours for DNS propagation
```

---

### Issue 4: CloudFront Can't Find Certificate

**Symptom:** `InvalidViewerCertificate` error

**Diagnosis:**

```bash
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1 \
  --query "Certificate.Status"
```

**Common Causes:**
1. Certificate not in `us-east-1` region
2. Certificate not validated yet
3. ACM propagation delay

**Fix:**

Already handled by `time_sleep` resource (60s wait), but if still failing:

```hcl
# Increase wait time in modules/static_hosting/main.tf
resource "time_sleep" "wait_for_acm_propagation" {
  create_duration = "120s"  # Increase from 60s
}
```

Then re-apply:

```bash
terraform apply
```

---

## Onboarding Checklist

Use this checklist for each new client:

- [ ] **Step 1:** Add domain to `terraform.tfvars`
- [ ] **Step 2:** Run `terraform plan` and review changes
- [ ] **Step 3:** Run `terraform apply` (wait 20-30 mins)
- [ ] **Step 4:** Get nameservers from Route53
- [ ] **Step 5:** Delegate nameservers at registrar
- [ ] **Step 6:** Wait 1-2 hours, verify DNS resolution
- [ ] **Step 7:** Verify SES domain verification
- [ ] **Step 8:** Test email sending (if dynamic)
- [ ] **Step 9:** Test application access (HTTPS)
- [ ] **Step 10:** Monitor CloudWatch logs
- [ ] **Step 11:** Notify client that domain is live
- [ ] **Step 12:** Document in client onboarding tracker

---

## Bulk Onboarding (10+ Clients)

For onboarding multiple clients at once:

### Step 1: Prepare terraform.tfvars

```hcl
client_domains = {
  "client1"  = { domain = "client1.com",  priority = 100 },
  "client2"  = { domain = "client2.com",  priority = 101 },
  "client3"  = { domain = "client3.com",  priority = 102 },
  # ... up to 100+
}
```

### Step 2: Apply in Batches

**Recommendation:** Apply in batches of 10 to avoid rate limits

```bash
# Batch 1: clients 1-10
terraform apply -target=module.route53_acm -target=module.client_deployment

# Wait for ACM validation (20 mins)

# Batch 2: clients 11-20
# ... repeat
```

### Step 3: Automate Nameserver Delegation

Create a script to automate nameserver updates:

```bash
#!/bin/bash
# get_nameservers.sh

for client in client1 client2 client3; do
  ZONE_ID=$(terraform output -json route53_zone_ids | jq -r ".${client}")
  NS=$(aws route53 get-hosted-zone --id $ZONE_ID --query "DelegationSet.NameServers" --output json)
  echo "${client}: ${NS}"
done
```

---

## Post-Onboarding Tasks

After successful onboarding:

1. **Update Documentation**
   - Add client to internal wiki
   - Document any custom configurations

2. **Set Up Monitoring**
   - Verify CloudWatch alarms are firing
   - Add client to monitoring dashboard

3. **Cost Tracking**
   - Tag resources with client name
   - Set up cost allocation reports

4. **Client Communication**
   - Send welcome email with:
     - Domain is live
     - Email configuration details
     - Support contact information

---

## Offboarding Process

To remove a client:

### Step 1: Remove from terraform.tfvars

```hcl
client_domains = {
  # "oldclient" = { domain = "oldclient.com", priority = 100 },  # REMOVE THIS
  "sree84s" = { domain = "sree84s.site", priority = 101 },
}
```

### Step 2: Apply Changes

```bash
terraform apply
```

**Resources Destroyed:**
- Route53 hosted zone
- SES domain identity
- ECS service (dynamic)
- CloudFront distribution (static)
- S3 bucket (static)
- ALB listener rule (dynamic)

**Note:** ACM certificate will be updated to remove the domain's SANs

### Step 3: Backup Data

Before offboarding, backup:

```bash
# Backup S3 bucket (static)
aws s3 sync s3://venturemond-infra-oldclient-static-content/ ./backup/oldclient/

# Backup SES emails
aws s3 sync s3://venturemond-infra-ses-inbound-storage-2026/ ./backup/oldclient-emails/ --exclude "*" --include "*oldclient.com*"
```

---

## Appendix: Quick Reference

### Terraform Commands

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy specific client
terraform destroy -target=module.client_deployment[\"oldclient\"]

# Show outputs
terraform output

# Refresh state
terraform refresh
```

### AWS CLI Commands

```bash
# Get hosted zone nameservers
aws route53 get-hosted-zone --id <zone-id> --query "DelegationSet.NameServers"

# Check SES verification
aws ses get-identity-verification-attributes --identities <domain>

# Check ECS service
aws ecs describe-services --cluster <cluster> --services <service>

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check CloudFront distribution
aws cloudfront get-distribution --id <distribution-id>
```

---

**Runbook Version:** 2.0  
**Last Updated:** 2026-02-08  
**Maintained By:** Infrastructure Team  
**Next Review:** 2026-03-08
