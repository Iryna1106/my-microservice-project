# Providers this module uses. The actual provider CONFIG lives in the root
# (providers.tf); here we only declare which providers we need so Terraform
# passes the configured ones down into this module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Used to read the cluster OIDC endpoint's certificate thumbprint.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
