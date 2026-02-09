# Multi-Domain Hosting Platform on AWS

This repository contains the Terraform configuration for a scalable, multi-tenant hosting platform on AWS. The platform is designed to efficiently host 70-100 client domains, offering two distinct hosting models:

1.  **Full Service (Dynamic):** Hosting via AWS ECS Fargate, managed end-to-end.
2.  **Domain Only (Static):** High-performance hosting via S3 and CloudFront, allowing clients to maintain their own content.

## 🚀 Key Features

* **Infrastructure as Code (IaC):** 100% provisioned via Terraform.
* **Scalable Hosting:** Uses AWS ECS (Fargate) and Application Load Balancer (ALB) with Host-Based Routing.
* **High Performance Static Hosting:** Utilizes S3 + CloudFront (CDN) for fast static site delivery.
* **Secure:** HTTPS via AWS ACM and private networking (VPC).
* **Business Email:** SES and Lambda for reliable email forwarding (`support@client.com` to personal inbox).

## ⚙️ Architecture Highlights

The system routes traffic based on the client domain:
* **Dynamic Client:** Traffic goes to ALB -> ECS Service.
* **Static Client:** Traffic goes to Route 53 -> CloudFront -> S3.

## 🛠️ Getting Started

1.  Clone this repository.
2.  Run `terraform init` and `terraform apply`.
3.  Refer to the `Runbook.md` for client onboarding procedures.

## 🖼️ Architecture Flow Diagram

This diagram provides a high-level visual representation of the two distinct client traffic flows (Dynamic and Static).

![Multi-Domain Hosting Architecture Flow](images/multi-domain-architecture.png)