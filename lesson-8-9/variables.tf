# variables.tf — the knobs you can turn WITHOUT editing any other file.
#
# How to set them (any of these):
#   • put them in a `terraform.tfvars` file (copy terraform.tfvars.example), or
#   • pass them on the command line: terraform apply -var="aws_region=eu-central-1", or
#   • use environment variables: export TF_VAR_aws_region=eu-central-1
#
# Every variable has a default, so `terraform apply` also works with none set.
# (Your AWS account ID is detected automatically — see locals.tf — so it is NOT
#  a variable here; you never have to type it.)

variable "aws_region" {
  description = "AWS region to deploy everything into. Must have at least 3 Availability Zones."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = <<-EOT
    Short lowercase/hyphenated prefix used to name resources (VPC, ECR, EKS
    cluster, DynamoDB lock table, S3 state bucket).
    ⚠️ If you change this, also update the matching literal names in backend.tf —
    a backend block cannot read variables (Terraform limitation).
  EOT
  type        = string
  default     = "lesson-8-9"
}

# --- GitOps (CI/CD) settings — WHERE the Helm chart lives in Git ---
# All three must agree: the chart really exists on this branch at this path, the
# Jenkins pipeline pushes the tag update to this branch, and Argo CD watches it.

variable "gitops_repo_url" {
  description = "HTTPS URL of the Git repo that holds the Helm chart Argo CD watches."
  type        = string
  default     = "https://github.com/Iryna1106/my-microservice-project.git"
}

variable "gitops_branch" {
  description = <<-EOT
    Git branch used for GitOps. Jenkins pushes the updated image tag to this
    branch, and Argo CD watches it. The assignment says "push to main", but this
    project keeps its coursework on the lesson branch, so the default is
    'lesson-8-9'. Change it to 'main' if you merge your chart there instead.
  EOT
  type        = string
  default     = "lesson-8-9"
}

variable "gitops_chart_path" {
  description = "Path (inside the repo) to the Django Helm chart Argo CD deploys."
  type        = string
  default     = "lesson-8-9/charts/django-app"
}
