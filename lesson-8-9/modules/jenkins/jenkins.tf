# =============================================================================
#  JENKINS (CI) — installed from its official Helm chart, driven by Terraform.
#
#  Jenkins runs INSIDE the EKS cluster. When a pipeline runs, the Kubernetes
#  plugin launches a short-lived "agent" pod (with Kaniko + Git containers) to
#  do the heavy work, then throws it away. That keeps the controller light and
#  means builds scale with the cluster.
# =============================================================================

# The namespace Jenkins lives in — its own "room" in the cluster.
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
  }
}

# The Jenkins Helm release. All the knobs are set in values.yaml (rendered as a
# template so our Terraform variables flow into it).
resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"

  # Empty string => install the latest chart version.
  version = var.chart_version != "" ? var.chart_version : null

  # First boot downloads plugins, so give it generous time and wait until the
  # controller is actually Ready before Terraform reports success.
  timeout = 900
  wait    = true

  values = [
    templatefile("${path.module}/values.yaml", {
      admin_user       = var.admin_user
      service_type     = var.service_type
      storage_class    = var.storage_class
      persistence_size = var.persistence_size
    })
  ]
}
