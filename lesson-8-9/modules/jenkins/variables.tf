variable "namespace" {
  description = "Kubernetes namespace to install Jenkins into."
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = <<-EOT
    Version of the Jenkins Helm chart to install. Leave empty ("") to install
    the latest available version. Pin a version here for reproducible installs
    (find versions with: helm search repo jenkins/jenkins --versions).
  EOT
  type        = string
  default     = ""
}

variable "service_type" {
  description = "How to expose the Jenkins UI: LoadBalancer (public URL) or ClusterIP (port-forward only)."
  type        = string
  default     = "LoadBalancer"
}

variable "storage_class" {
  description = "StorageClass for the Jenkins data disk. 'gp2' is the EKS default (backed by the EBS CSI driver)."
  type        = string
  default     = "gp2"
}

variable "persistence_size" {
  description = "Size of the Jenkins data disk (PersistentVolumeClaim)."
  type        = string
  default     = "8Gi"
}

variable "admin_user" {
  description = "Username of the Jenkins admin account (password is auto-generated)."
  type        = string
  default     = "admin"
}
