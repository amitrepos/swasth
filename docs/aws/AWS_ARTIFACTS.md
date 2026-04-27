# Swasth AWS Artifacts

**Account ID:** `619248810929`
**IAM User:** `amitrepos`
**Region:** `ap-south-1` (Mumbai)
**Created:** 2026-04-27
**Purpose:** Production migration from Hetzner (`65.109.226.36`) → AWS Mumbai for Play Store release + DPDPA compliance.

> This file is the source of truth for all Swasth-owned AWS objects.
> Update it every time a new object is created or deleted.
> Tag every new resource with `Project=swasth` to aid cost filtering.

---

## EC2

| Name | Instance ID | Type | AMI | State | Purpose |
|---|---|---|---|---|---|
| `swasth-prod` | `i-09f5154e94406f5f4` | t3.micro | Amazon Linux 2023 (`ami-0e12ffc2dd465f6e4`) | running | FastAPI backend + Flutter web + Nginx |

**SSH access:**
```bash
ssh -i ~/.ssh/swasth-prod-key.pem ec2-user@13.127.215.113
```

**Storage:** 20 GB gp3 (`/dev/nvme0n1p1`)

---

## Elastic IPs

| IP | Allocation ID | Association | Purpose |
|---|---|---|---|
| `13.127.215.113` | (auto-allocated 2026-04-27) | `swasth-prod` EC2 | Static IP for `api.swasth.health` DNS |

> Cost: $0/mo while attached to a running instance. Becomes ~$3.65/mo if instance is stopped.

---

## Key Pairs

| Name | Key ID | Region | Local path | Created |
|---|---|---|---|---|
| `swasth-prod-key` | `key-0a3d068d386c1334b` | ap-south-1 | `~/.ssh/swasth-prod-key.pem` | 2026-04-27 |

> The `.pem` file is NOT committed to git. Keep it in `~/.ssh/` with `chmod 400`.

---

## Security Groups

| Name | SG ID | VPC | Rules | Purpose |
|---|---|---|---|---|
| `swasth-ec2-sg` | `sg-0383cfbd2ca13f4f7` | `vpc-7f17e814` (default) | SSH:22 → `122.172.86.14/32`, HTTP:80 → `0.0.0.0/0`, HTTPS:443 → `0.0.0.0/0` | EC2 inbound rules |

> SSH is locked to Amit's current IP (`122.172.86.14`). Update if IP changes:
> ```bash
> aws ec2 revoke-security-group-ingress --region ap-south-1 --group-id sg-0383cfbd2ca13f4f7 --protocol tcp --port 22 --cidr <OLD_IP>/32
> aws ec2 authorize-security-group-ingress --region ap-south-1 --group-id sg-0383cfbd2ca13f4f7 --protocol tcp --port 22 --cidr <NEW_IP>/32
> ```

---

## VPC / Networking

| Resource | ID | Notes |
|---|---|---|
| VPC | `vpc-7f17e814` | Default VPC, ap-south-1 |

> Using the default VPC for POC simplicity. When post-funding, create a dedicated `swasth-vpc` (10.0.0.0/16) with public + private subnets.

---

## RDS (deferred — post AWS Activate credits)

| Name | Engine | Type | Status | Notes |
|---|---|---|---|---|
| `swasth-prod-db` | PostgreSQL 15 | db.t3.micro | **NOT CREATED YET** | Deferred until AWS Activate credits land. POC uses Postgres on EC2. |

---

## S3 (deferred)

| Bucket | Purpose | Status |
|---|---|---|
| `swasth-ocr-images` | Future OCR photo uploads | **NOT CREATED YET** |
| `swasth-archive` | Hetzner final snapshot backup | **NOT CREATED YET** |

---

## DNS (not AWS — external provider)

| Domain | Record | Points to | Purpose |
|---|---|---|---|
| `api.swasth.health` | A | `13.127.215.113` | Backend API endpoint (to be created on DNS cutover) |
| `swasth.health` | A | `65.109.226.36` | Interest form (Hetzner — unchanged for now) |

> DNS cutover: change `api.swasth.health` A record to `13.127.215.113` on cutover day.

---

## Cost Tracker (POC phase)

| Resource | Monthly cost |
|---|---|
| EC2 t3.micro (on-demand) | ~$8.50 OR $0 if free tier active |
| Elastic IP (attached, running) | $0 |
| gp3 storage 20 GB | ~$1.60 OR $0 if free tier active |
| **Total** | **~$10/mo (or $0 on free tier)** |

> Free tier: 750 hrs/mo t3.micro + 30 GB EBS for 12 months from account creation.
> Check eligibility: AWS Console → Billing → Free Tier.

---

## TODO: Non-Swasth Audit (do separately)

A global search of this AWS account may reveal objects from other projects (Predixarena, ProductIQ, etc. — seen in Hetzner PM2 list) that are costing money.

**Planned action (separate session):**
- `aws ec2 describe-instances --region ap-south-1` — list all EC2
- `aws ec2 describe-volumes --region ap-south-1` — orphaned EBS volumes
- `aws s3 ls` — all buckets
- Tag Swasth resources with `Project=swasth`, everything else investigate + delete if not needed
- Check all regions: `ap-south-1`, `eu-west-1` (current CLI default), `us-east-1`

**Do NOT delete anything without identifying it first.**

---

## Change Log

| Date | Action | Object | Notes |
|---|---|---|---|
| 2026-04-27 | Created | Key pair `swasth-prod-key` | Imported from existing `~/.ssh/swasth-prod-key.pem` |
| 2026-04-27 | Created | Security group `swasth-ec2-sg` | SSH restricted to `122.172.86.14` |
| 2026-04-27 | Created | EC2 `swasth-prod` | t3.micro, Amazon Linux 2023, 20 GB gp3 |
| 2026-04-27 | Created | Elastic IP `13.127.215.113` | Attached to `swasth-prod` |
