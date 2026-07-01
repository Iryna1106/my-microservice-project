# Providers this module uses. Config is inherited from the project root
# (../../providers.tf); here we only declare the requirement.
#
# (The assignment note "переносимо з модуля jenkins" — the Kubernetes+Helm
#  provider declaration is the same shape as the jenkins module's.)
terraform {
  required_providers {
    # Installs the Argo CD chart AND the local "app-of-apps" chart.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    # Creates the 'argocd' namespace and (after install) reads the admin secret.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
}
