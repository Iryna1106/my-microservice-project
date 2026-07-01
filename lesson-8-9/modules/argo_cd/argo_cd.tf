# =============================================================================
#  ARGO CD (CD) — installed from its official Helm chart, driven by Terraform.
#
#  Argo CD is the "GitOps robot": it watches the Git repo and makes the cluster
#  match whatever the Helm chart in Git says. When Jenkins pushes a new image
#  tag into values.yaml, Argo CD notices and rolls it out automatically.
#
#  Two Helm releases here:
#    1. argocd        — Argo CD itself (controller, server/UI, repo-server…).
#    2. app_of_apps   — a tiny local chart that creates ONE Argo CD Application
#                       object telling Argo what to deploy and from where.
# =============================================================================

# Argo CD's own "room" in the cluster.
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

# ---- 1. Install Argo CD ----
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  # Empty string => latest chart version.
  version = var.chart_version != "" ? var.chart_version : null

  timeout = 900
  wait    = true

  values = [
    templatefile("${path.module}/values.yaml", {
      service_type = var.service_type
    })
  ]
}

# ---- 2. Register the Application (app-of-apps pattern) ----
# This installs the local chart in ./charts, which renders an Argo CD
# "Application" (and, optionally, a repository credential). It MUST run after
# Argo CD is installed, because the Application is a Custom Resource whose
# definition (CRD) is created by the argocd release above.
resource "helm_release" "app_of_apps" {
  name      = "${var.app_name}-app"
  namespace = kubernetes_namespace.argocd.metadata[0].name
  chart     = "${path.module}/charts"

  depends_on = [helm_release.argocd]

  # Feed the Git coordinates into the app-of-apps chart's values.
  set {
    name  = "argocdNamespace"
    value = var.namespace
  }
  set {
    name  = "repoURL"
    value = var.git_repo_url
  }
  set {
    name  = "targetRevision"
    value = var.gitops_branch
  }
  set {
    name  = "path"
    value = var.chart_path
  }
  set {
    name  = "appName"
    value = var.app_name
  }
  set {
    name  = "destinationNamespace"
    value = var.app_namespace
  }
  # The ECR image URL Terraform built from your account/region. The app-of-apps
  # chart passes this to Argo as a Helm parameter that overrides image.repository.
  set {
    name  = "imageRepository"
    value = var.ecr_repository_url
  }
}
