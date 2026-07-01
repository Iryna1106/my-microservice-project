# main.tf — wires all the modules together.
#
# Lessons 8–9 build on lesson 7 (S3 backend + VPC + ECR + EKS) and ADD two new
# modules on top of the running cluster:
#   • jenkins  — CI: builds the Docker image and pushes it to ECR, then updates
#                the image tag in the Helm chart and pushes that change to Git.
#   • argo_cd  — CD: watches Git and syncs the updated chart into the cluster.

# --- S3 + DynamoDB backend (Terraform state storage & locking) ---
# Names are built from var.project_name + your account id (see locals.tf).
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = local.state_bucket_name # ⚠️ must match backend.tf
  table_name  = local.lock_table_name
}

# --- Network (VPC with public & private subnets) ---
# This is the SAME network setup from the previous lesson; the EKS cluster
# below is placed INSIDE it. The AZs come from the chosen region automatically.
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = local.azs
  vpc_name           = "${var.project_name}-vpc"
}

# --- ECR (Docker image registry for the Django image) ---
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "${var.project_name}-ecr"
  scan_on_push = true
}

# --- EKS (the Kubernetes cluster, running in the VPC above) ---
# In lessons 8–9 this module ALSO creates the OIDC provider + EBS CSI driver
# (so Jenkins can get a persistent disk) and grants the worker nodes ECR *push*
# rights (so Kaniko can push images). See modules/eks/aws_ebs_csi_driver.tf.
module "eks" {
  source = "./modules/eks"

  cluster_name    = "${var.project_name}-eks"
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

# --- Jenkins (CI) — installed via its Helm chart, driven by Terraform ---
# Runs INSIDE the cluster. It spins up short-lived Kubernetes "agent" pods
# (Kaniko + Git) to build and push images. See modules/jenkins/.
module "jenkins" {
  source = "./modules/jenkins"

  namespace     = "jenkins"
  service_type  = "LoadBalancer" # gives the Jenkins UI a public URL
  storage_class = "gp2"          # the default EKS StorageClass (backed by EBS CSI)

  # Don't install Jenkins until the cluster AND its EBS CSI driver are ready,
  # otherwise the Jenkins data disk (PersistentVolumeClaim) stays "Pending".
  depends_on = [module.eks]
}

# --- Argo CD (CD) — installed via its Helm chart, driven by Terraform ---
# Watches the Git repo below and keeps the cluster in sync with the Helm chart.
module "argo_cd" {
  source = "./modules/argo_cd"

  namespace    = "argocd"
  service_type = "LoadBalancer" # gives the Argo CD UI a public URL

  # What Argo CD should deploy and where it should watch for changes.
  git_repo_url  = var.gitops_repo_url
  gitops_branch = var.gitops_branch # the branch Jenkins pushes tag updates to
  chart_path    = var.gitops_chart_path
  app_name      = "django-app"
  app_namespace = "django" # namespace the Django app is deployed INTO

  # The ECR URL Terraform built from YOUR account + region. Argo CD injects it as
  # the image.repository, so it is never hard-coded in the chart's values.yaml.
  ecr_repository_url = module.ecr.repository_url

  # Argo CD also needs the cluster to exist before Helm can install it.
  depends_on = [module.eks]
}
