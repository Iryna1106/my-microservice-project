# main.tf — wires the four modules together.

# --- S3 + DynamoDB backend (Terraform state storage & locking) ---
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "my-microservice-lesson-7-tfstate-139214069645" # globally unique (account-id suffix)
  table_name  = "terraform-locks-lesson-7"
}

# --- Network (VPC with public & private subnets) ---
# This is the SAME network setup from the previous lesson; the EKS cluster
# below is placed INSIDE it.
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "lesson-7-vpc"
}

# --- ECR (Docker image registry for the Django image) ---
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-7-ecr"
  scan_on_push = true
}

# --- EKS (the Kubernetes cluster, running in the VPC above) ---
module "eks" {
  source = "./modules/eks"

  cluster_name    = "lesson-7-eks"
  cluster_version = "1.33"

  # Plug the cluster into the network created by the vpc module.
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  # Worker node sizing.
  # m7i-flex.large is free-tier-eligible (x86_64, 8 GB) — required because this
  # AWS account's Free Tier plan blocks non-eligible types like t3.medium.
  node_instance_types = ["m7i-flex.large"]
  node_desired_size   = 2
  node_min_size       = 2
  node_max_size       = 4
}
