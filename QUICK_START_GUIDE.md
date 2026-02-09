# Quick Start Guide - Scaling to 100+ Domains

## 🚀 Ready to Deploy

Your infrastructure is now configured for **automatic scaling to 100+ domains**. Follow these steps to deploy.

---

## 📝 Step-by-Step Deployment

### Step 1: Review Current Configuration

Check your current domains in `terraform.tfvars`.

### Step 2: Preview Changes

```bash
terraform plan
```

### Step 3: Apply Changes

```bash
terraform apply
```

---

## 🎯 Adding New Domains

### Add a Dynamic Domain (ECS + ALB)

Edit `terraform.tfvars`:

```hcl
client_domains = {
  "newclient" = { domain = "newclient.com", priority = 101 }
}
```

### Add a Static Domain (S3 + CloudFront)

Edit `terraform.tfvars`:

```hcl
static_client_configs = {
  "newstatic" = { domain_name = "newstatic.io" }
}
```

### Add a Subdomain (using existing Parent Zone)

Edit `terraform.tfvars`:

```hcl
static_client_configs = {
  "calvio_sub" = {
    domain_name      = "calvio.sree84s.site"  # The subdomain
    parent_zone_name = "sree84s.site"         # The EXISTING parent zone
  }
}
```

**Note:** This will create an A-record (Alias) in the *existing* `sree84s.site` hosted zone instead of creating a new hosted zone.

---

## 📊 Deployment Verification

After applying changes:

1. **Check S3 Bucket Name:**
   The bucket name will follow the pattern: `<project>-<key>-static-content`
   Example: `venturemond-infra-calvio_sub-static-content`

2. **Upload Static Files:**
   ```bash
   aws s3 cp ./index.html s3://venturemond-infra-calvio_sub-static-content/
   ```

3. **Check CloudFront URL:**
   Retrieve the CloudFront domain from Terraform outputs.

---

**Last Updated:** 2026-02-08
