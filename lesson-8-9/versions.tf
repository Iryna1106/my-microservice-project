terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Creates the AWS infrastructure (VPC, ECR, EKS, IAM, S3, DynamoDB).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Talks to the Kubernetes API of the EKS cluster (namespaces, service
    # accounts, storage classes, reading secrets for the admin passwords).
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }

    # Installs Helm charts (Jenkins, Argo CD, and the Argo "app-of-apps").
    # Pinned to 2.x on purpose: the provider config below uses the v2 `kubernetes {}`
    # block syntax (v3 changed it to a `kubernetes = {}` attribute).
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    # Reads the cluster's OIDC TLS certificate thumbprint — needed to create the
    # OIDC provider that IAM Roles for Service Accounts (IRSA) rely on.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
