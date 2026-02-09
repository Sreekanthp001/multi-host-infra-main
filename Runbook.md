# Operational Runbook: Multi-Domain Hosting Platform

This runbook serves as the comprehensive guide for the Operations Team managing the AWS Multi-Domain Hosting Infrastructure. Its primary purpose is to enable any new DevOps Engineer to onboard, manage, and troubleshoot client sites with minimal required context.

##  Platform Architecture Reference

Before performing any operational steps, please reference the architecture diagram below to understand the two distinct client flows within the platform.

![Multi-Domain Hosting Architecture Flow](images/multi-domain-architecture.png)

## 1. Onboarding a New Client Domain

Our platform supports two distinct hosting models. **Always confirm the client's content management preference before starting.**

### 1.1. Client Type 1: Full Service Hosting (ECS/Fargate)

**Use Case:** For dynamic applications (e.g., Node.js, PHP) where the platform manages deployment and scaling.
**Goal:** Provision a dedicated ECS Service, ALB Listener Rule, and routing.

| Step | Action | Why We Do This |
| :--- | :--- | :--- |
| **1. Code and Repo Setup** | Create the client's Git repository and ensure a working `Dockerfile` is present. | The CI/CD pipeline requires a valid source and Docker build definition. |
| **2. Terraform Variables Update** | Open `variables.tf` and add the new domain to the `client_domains` list. | This ensures Terraform recognizes the new client and loops through the module. |
| **3. Initial Terraform Apply** | Execute `terraform apply`. The deployment will *pause* after creating the Route 53 Hosted Zone and requesting the ACM Certificate. | The ACM (Certificate Manager) must receive DNS validation before the ALB/ECS setup can proceed. |
| **4. DNS Delegation (Client Action)** | Provide the **NS (Name Server) records** from the newly created Route 53 Hosted Zone to the client. The client must update these on their domain registrar (GoDaddy, etc.). | This delegates domain management to our AWS environment, allowing ACM to validate the certificate. |
| **5. Wait for ACM** | Wait 5–15 minutes. Confirm the ACM Certificate status changes from `Pending Validation` to **`Issued`** in the AWS Console. | This is the crucial blocking step. Deployment must not proceed until the certificate is valid. |
| **6. Final Terraform Apply** | Execute `terraform apply` again. | This completes the ECS Service, Task Definition, and finally configures the ALB Host-Based Rule, pointing traffic to the new ECS service. |

### 1.2. Client Type 2: Static Hosting (S3/CloudFront)

**Use Case:** For static sites (HTML/CSS/JS) where the client manages content. This offers high performance and cost efficiency.
**Goal:** Provision a private S3 bucket, a CloudFront CDN, and a direct Route 53 alias (bypassing the ALB). 

| Step | Action | Why We Do This |
| :--- | :--- | :--- |
| **1. Terraform Variables Update** | Open `variables.tf` and add the new domain to the `static_client_domains` list. | This activates the separate `static_client_deployment` module. |
| **2. DNS/ACM Validation** | Follow **Steps 3, 4, and 5** from the Client Type 1 process exactly. | Both hosting types require the same DNS delegation and ACM validation process. |
| **3. Final Deployment** | Execute `terraform apply` after ACM is **`Issued`**. | This creates the private S3 bucket, the CloudFront distribution with HTTPS (using the validated ACM), and the Route 53 A-Alias record pointing to the CDN. |
| **4. Client Handoff (Content)** | Provide the client with the name of their new S3 bucket (e.g., `client-x-static-assets`). Give them temporary IAM credentials or instructions to upload their content. | The client is responsible for placing their `index.html` and assets directly into this S3 bucket. |

## 2. Incident Response and Troubleshooting

If a site goes down, follow these steps sequentially.

### 2.1. ECS Service (Type 1) Health Check Failures

**Symptom:** Client reports site down, or ALB Target Group is unhealthy.

1.  **Check ECS Tasks:** Verify the "Desired" task count matches the "Running" task count in the ECS Service console.
2.  **Examine Logs:** Navigate to CloudWatch Logs for the ECS Task's Log Group. Search for keywords like `ERROR`, `FATAL`, or `Bind failed`. This usually points to application bugs or environment misconfiguration (e.g., incorrect environment variable).
3.  **Validate Security:** Confirm the ECS Task Security Group allows traffic on the required port from the ALB Security Group. A firewall block is a common cause of Target Group failure.
4.  **Force Redeployment:** If logs are clean but the task is unhealthy, use the `aws ecs update-service --force-new-deployment` command. This forces the service to pull a fresh image and restart, often resolving transient issues.

### 2.2. Email Forwarding Failure (SES/Lambda)

**Symptom:** Email sent to `support@client.com` is not delivered to the final personal inbox.

1.  **Verify SES Flow:** Check the SES Console -> Rule Sets. Ensure the inbound email triggered the rule (check the `Monitoring` tab).
2.  **Check S3 for Raw Mail:** Confirm the raw email file (long alphanumeric ID) is present in the inbound S3 bucket (`sree84s-ses-inbound-mail-storage...`). If the file is missing, the SES Rule is failing.
3.  **Inspect Lambda Logs:** Check the CloudWatch Logs for the `vm-hosting-ses-forwarder-lambda` function. Look for two main failure types:
    * **Permissions:** Lambda cannot read from S3 (`s3:GetObject`) or cannot send via SES (`ses:SendRawEmail`). **Fix:** Update the Lambda's IAM Execution Role.
    * **Timeouts:** If the Lambda is running out of time, increase the timeout setting.

### 2.3. Certificate/HTTPS Issues

**Symptom:** Browser displays "Not Secure" or a certificate expiration warning.

1.  **Check ACM Status:** Navigate to the ACM console and find the affected domain's certificate. Verify the status is **`Issued`** and not `Pending` or `Expired`.
2.  **Validate Route 53:** If the certificate is `Pending`, ensure the required CNAME validation record (created by ACM) exists and is correctly propagated in the Route 53 Hosted Zone. **This is usually a DNS propagation issue.**
3.  **Verify ALB/CloudFront:** Check that the ALB Listener or CloudFront Distribution is still pointing to the correct, non-expired ACM ARN.

## 3. Offboarding a Client Domain

A clean offboarding is essential for cost management and security.

1.  **Remove Terraform References:** Delete the client's domain from all applicable Terraform variables and remove the entire client's module block (either `client_deployment` or `static_client_deployment`) from `main.tf`.
2.  **Verify Destruction Plan:** Run `terraform plan`. **CRITICAL:** Carefully review the output to ensure only the specific client's resources (ECS Service, Route 53 Zone, CloudFront, etc.) are slated for destruction, and no core infrastructure (VPC, ALB, ECS Cluster) is affected.
3.  **Execute Cleanup:** Run `terraform apply` to destroy the AWS resources.
4.  **S3 Manual Cleanup:** If the client was Type 2 (Static Hosting), the associated S3 bucket will likely be non-empty. Terraform cannot destroy non-empty buckets. Manually delete all files within that S3 bucket before destroying the bucket resource.