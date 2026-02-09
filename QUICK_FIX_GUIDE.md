# Quick Fix Application Guide

## What Was Fixed

✅ **Fix 1**: EC2 Duplicate Security Group Error  
   - Added unique suffix using `random_id` resource
   - File: `modules/ecs/main.tf`

✅ **Fix 2**: SES Lambda Permission Missing  
   - Added `aws_lambda_permission` for SES to invoke Lambda
   - File: `modules/ses_config/main.tf`

✅ **Fix 3**: CloudFront ACM Certificate Timing  
   - Added 60-second wait timer for certificate propagation
   - File: `modules/static_hosting/main.tf`

---

## Apply These Fixes

### Step 1: Initialize Terraform (Already Done ✓)
```bash
terraform init -upgrade
```
**Status**: ✅ Completed - Providers installed successfully

### Step 2: Validate Configuration (Already Done ✓)
```bash
terraform validate
```
**Status**: ✅ Success! The configuration is valid.

### Step 3: Review the Plan
```bash
terraform plan
```

**What to Look For:**
- `random_id.sg_suffix` will be created
- `aws_security_group.ecs_tasks_sg` will be created with new name
- `aws_lambda_permission.allow_ses_invoke` will be created
- `time_sleep.wait_for_acm_propagation` will be created
- `aws_cloudfront_distribution.s3_dist` will be updated

### Step 4: Apply the Changes
```bash
terraform apply
```

**Expected Timeline:**
- Security group creation: ~5 seconds
- Lambda permission creation: ~3 seconds
- ACM certificate wait: **60 seconds** (intentional delay)
- CloudFront distribution: ~10-15 minutes (AWS propagation)

---

## Troubleshooting

### If You Still Get Security Group Error
**Symptom**: `InvalidGroup.Duplicate` error persists

**Solution**: The old security group might still exist. Either:
1. Delete it manually in AWS Console
2. Or import it into Terraform state:
   ```bash
   terraform import module.ecs.aws_security_group.ecs_tasks_sg sg-xxxxxxxxx
   ```

### If SES Lambda Permission Fails
**Symptom**: `InvalidLambdaFunction` error persists

**Check**:
1. Lambda function exists: `aws lambda get-function --function-name venturemond-infra-ses-bounce-complaint-handler`
2. SES service principal is correct: `ses.amazonaws.com`

### If CloudFront Still Can't Find Certificate
**Symptom**: `InvalidViewerCertificate` error persists

**Solutions**:
1. Increase wait time to 120 seconds in `modules/static_hosting/main.tf`:
   ```hcl
   create_duration = "120s"
   ```
2. Verify certificate is in `us-east-1` region
3. Check certificate status:
   ```bash
   aws acm describe-certificate --certificate-arn <your-cert-arn> --region us-east-1
   ```

---

## Verification Commands

After `terraform apply` succeeds:

### 1. Verify Security Group
```bash
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=venturemond-infra-ecs-tasks-sg" --region us-east-1
```

### 2. Verify Lambda Permission
```bash
aws lambda get-policy --function-name venturemond-infra-ses-bounce-complaint-handler --region us-east-1
```
Look for `"Principal": "ses.amazonaws.com"` in the output.

### 3. Verify CloudFront Distribution
```bash
aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Status]' --output table
```
Status should be `Deployed`.

---

## Rollback Plan

If something goes wrong:

```bash
# Destroy only the new resources
terraform destroy -target=random_id.sg_suffix
terraform destroy -target=module.ses_config.aws_lambda_permission.allow_ses_invoke
terraform destroy -target=time_sleep.wait_for_acm_propagation

# Or revert the code changes using git
git checkout modules/ecs/main.tf
git checkout modules/ses_config/main.tf
git checkout modules/static_hosting/main.tf
git checkout providers.tf
```

---

## Next Steps

1. Run `terraform plan` to review changes
2. Run `terraform apply` when ready
3. Monitor the apply process (expect ~15-20 minutes total)
4. Verify all resources are created successfully

**Need Help?** Check `TERRAFORM_FIXES_SUMMARY.md` for detailed explanations.
