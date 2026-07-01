variable "namespace" {
  description = "Kubernetes namespace to install Argo CD into."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = <<-EOT
    Version of the argo-cd Helm chart to install. Leave empty ("") to install
    the latest available version. Pin for reproducible installs
    (helm search repo argo/argo-cd --versions).
  EOT
  type        = string
  default     = ""
}

variable "service_type" {
  description = "How to expose the Argo CD UI/API: LoadBalancer (public URL) or ClusterIP (port-forward)."
  type        = string
  default     = "LoadBalancer"
}

# --- What the Argo CD Application should watch and deploy ---

variable "git_repo_url" {
  description = "HTTPS URL of the Git repo that holds the Helm chart."
  type        = string
}

variable "gitops_branch" {
  description = "Git branch (targetRevision) Argo CD watches for chart changes."
  type        = string
}

variable "chart_path" {
  description = "Path inside the repo to the Helm chart Argo CD deploys."
  type        = string
}

variable "app_name" {
  description = "Name of the Argo CD Application (and the Helm release it manages)."
  type        = string
  default     = "django-app"
}

variable "app_namespace" {
  description = "Namespace the Django app is deployed INTO (Argo creates it)."
  type        = string
  default     = "django"
}

variable "ecr_repository_url" {
  description = <<-EOT
    ECR repository URL (e.g. <account>.dkr.ecr.<region>.amazonaws.com/<repo>).
    Argo CD injects it as the Helm value image.repository, so the account id is
    not hard-coded in the chart. Leave "" to keep whatever is in the chart's
    values.yaml instead.
  EOT
  type        = string
  default     = ""
}
