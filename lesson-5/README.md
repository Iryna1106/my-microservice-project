# Lesson 5 — AWS Infrastructure with Terraform

Terraform configuration that provisions AWS infrastructure as three reusable
**modules**:

1. **s3-backend** — an S3 bucket (versioned + encrypted) and a DynamoDB table for
   Terraform remote **state storage and locking**.
2. **vpc** — a Virtual Private Cloud with **3 public** and **3 private** subnets,
   an Internet Gateway, a NAT Gateway, and route tables.
3. **ecr** — an Elastic Container Registry repository for Docker images, with
   **scan-on-push** and an access policy.

## 📁 Project structure

```
lesson-5/
├── main.tf              # connects the three modules together
├── backend.tf           # S3 + DynamoDB remote-state backend
├── providers.tf         # AWS provider (region)
├── versions.tf          # required Terraform & provider versions
├── outputs.tf           # combined outputs from all modules
├── README.md            # this file
├── .gitignore           # ignores .terraform/, *.tfstate, etc.
└── modules/
    ├── s3-backend/      # S3 bucket + DynamoDB lock table
    │   ├── s3.tf
    │   ├── dynamodb.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── vpc/             # VPC, subnets, gateways, routing
    │   ├── vpc.tf
    │   ├── routes.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ecr/             # ECR repository
        ├── ecr.tf
        ├── variables.tf
        └── outputs.tf
```

## ✅ Prerequisites

- An **AWS account**.
- **AWS credentials** configured locally — e.g. run `aws configure`, or export
  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
- **Terraform >= 1.5** installed.
- Edit the **S3 bucket name** so it is **globally unique** (S3 names are shared
  across all AWS accounts worldwide). Change it in **two** places, keeping them
  identical:
  - `main.tf` → `module "s3_backend"` → `bucket_name`
  - `backend.tf` → `backend "s3"` → `bucket`

## ▶️ Everyday commands

```bash
terraform init      # download providers / connect the backend
terraform plan      # preview changes — creates nothing
terraform apply     # create or update the real AWS resources
terraform destroy   # delete everything this project created
```

## 🧩 Modules explained

### `modules/s3-backend`

Creates the storage for Terraform's **state file** (the file that records what
infrastructure exists):

- **S3 bucket** — holds the state file. **Versioning** is enabled so every change
  is kept and you can roll back. The bucket is **encrypted** and **all public
  access is blocked**.
- **DynamoDB table** (`LockID` key) — Terraform writes a **lock** here while
  applying changes, so two people can't run `apply` at the same time and corrupt
  the state.
- **Outputs:** the S3 bucket URL and the DynamoDB table name.

### `modules/vpc`

Builds the network:

- **VPC** with CIDR `10.0.0.0/16` — your own isolated network.
- **3 public subnets** (`10.0.1–3.0/24`) — resources here can be reached from the
  internet (via the Internet Gateway).
- **3 private subnets** (`10.0.4–6.0/24`) — hidden from the internet.
- **Internet Gateway** — the door to the internet for the public subnets.
- **NAT Gateway** — lets the private subnets make _outbound_ internet calls
  (e.g. software updates) while staying unreachable from outside.
- **Route tables** — public subnets route to the Internet Gateway; private
  subnets route to the NAT Gateway.

### `modules/ecr`

Creates a private Docker image registry:

- **ECR repository** with **scan-on-push** enabled (images are automatically
  scanned for vulnerabilities).
- A **lifecycle policy** that keeps only the last 10 images (saves storage cost).
- A **repository access policy** allowing push/pull from your AWS account.
- **Output:** the repository URL (your `docker push` / `docker pull` target).
