# Providers this module uses. The actual provider CONFIG lives in the project
# root (../../providers.tf) — here we only DECLARE which providers we need, so
# Terraform hands the already-configured ones down into this module.
terraform {
  required_providers {
    # Installs the Jenkins Helm chart.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    # Creates the 'jenkins' namespace and (after install) reads the admin secret.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}
