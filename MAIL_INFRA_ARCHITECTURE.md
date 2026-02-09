# Multi-Tenant Business Email Infrastructure Design

## 1. Overview
The Business Email Hosting Infrastructure is designed to scale to 100+ client domains using a centralized Mail Exchange (`mx.webhizzy.in`) and a dynamic database-backed routing system. It ensures high deliverability, security, and ease of onboarding.

## 2. Core Components

### 2.1 Mail Servers (Postfix & Dovecot)
- **Postfix (MTA)**: Handles inbound and outbound SMTP traffic.
- **Dovecot (IMAP/MDA)**: Provides IMAP/POP3 access and manages mailbox storage (Maildir format).
- **Virtual Mailbox System**: Instead of system users, all mailboxes are "virtual" and managed in a database.

### 2.2 Dynamic Routing Database (MySQL/MariaDB)
The system uses three primary tables to manage multi-tenancy without config reloads:
- `virtual_domains`: List of all 100+ client domains.
- `virtual_users`: Email addresses and password hashes.
- `virtual_aliases`: Forwarding rules and alias mappings.

### 2.3 Security & Reputation
- **SSL/TLS**: Mandatory STARTTLS for SMTP and SSL for IMAP. Certificates managed via Let's Encrypt for `mx.webhizzy.in`.
- **Rspamd**: Modern spam filtering, hygiene checks, and DKIM signing.
- **DNS Records**: Automated provisioning of MX, SPF, DKIM, and DMARC for every onboarded domain.

## 3. Network Architecture
- **Inbound**: Port 25 (SMTP), 993 (IMAPS), 587 (Submission).
- **Isolation**: Mail infrastructure runs on dedicated EC2 instances, isolated from the ECS-based web application stack to prevent port conflicts (80/443).
- **IP Management**: Dedicated Elastic IP with PTR (Reverse DNS) record for `mx.webhizzy.in`.

## 4. Automation & IaC Strategy
1. **Terraform**: Provisions the EC2 instance, Elastic IP, and Route53 records.
2. **Ansible/Cloud-init**: Configures Postfix, Dovecot, and Rspamd on the instance.
3. **Dynamic Onboarding**: A logic module (SQL-based) that adds new domains to the database, which Postfix/Dovecot pick up instantly.

---

## 5. DNS Specification for Clients
Every client domain onboarded must have the following DNS configuration:

| Type | Name | Value | Priority |
|------|------|-------|----------|
| MX | @ | mx.webhizzy.in. | 10 |
| TXT | @ | v=spf1 mx -all | - |
| TXT | _dmarc | v=DMARC1; p=quarantine; adkim=s; aspf=s | - |
| TXT | dkim._domainkey | <Rspamd Generated Key> | - |
