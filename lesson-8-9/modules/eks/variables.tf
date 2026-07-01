variable "cluster_name" {
  description = "Name of the EKS (Kubernetes) cluster."
  type        = string
  default     = "lesson-7-eks"
}

variable "cluster_version" {
  description = <<-EOT
    Kubernetes version for the EKS control plane.
    If 'terraform apply' rejects this value, the error message lists the
    versions currently supported in your region (or run:
    'aws eks describe-cluster-versions'). Bump this default if needed.
  EOT
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "ID of the EXISTING VPC the cluster runs in (from the vpc module)."
  type        = string
}

variable "public_subnet_ids" {
  description = <<-EOT
    Public subnet IDs. The control plane uses these, and they are tagged so an
    internet-facing 'LoadBalancer' Service can place its load balancer here.
  EOT
  type        = list(string)
}

variable "private_subnet_ids" {
  description = <<-EOT
    Private subnet IDs. The worker nodes (EC2 machines) run here, hidden from
    the internet (best practice). The control plane also uses these.
  EOT
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance type(s) for the worker nodes."
  type        = list(string)
  default     = ["m7i-flex.large"]
}

variable "node_ami_type" {
  description = <<-EOT
    AMI family for the worker nodes. AL2023 is the current default for modern
    Kubernetes versions (the older 'AL2_x86_64' is being retired).
  EOT
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_desired_size" {
  description = "Number of worker nodes to start with."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}
