# providers.tf — configures HOW Terraform talks to each system.
#
# The AWS provider is used to build infrastructure. The kubernetes and helm
# providers are used to install things INTO the cluster (Jenkins, Argo CD).
# Those two are configured to point at the EKS cluster this project creates.

# AWS — all resources are created in this region (change via var.aws_region).
provider "aws" {
  region = var.aws_region
}

# A short-lived login token for the cluster's Kubernetes API. The `aws` CLI /
# STS generates it locally from your AWS credentials — the same thing that
# happens under the hood when you run `aws eks update-kubeconfig`.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# Kubernetes provider — used to create namespaces / service accounts and to read
# the auto-generated admin passwords for Jenkins and Argo CD.
#
# NOTE: the `host` and `cluster_ca_certificate` come from the eks module's
# outputs, which only become known AFTER the cluster is created. That is why the
# very first run needs a targeted apply of the cluster first (see backend.tf /
# README) — you cannot configure a connection to a cluster that doesn't exist yet.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Helm provider — installs the Jenkins, Argo CD and app-of-apps charts.
# It reuses the exact same cluster connection as the kubernetes provider above.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
