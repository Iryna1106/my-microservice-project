output "cluster_name" {
  description = "Name of the EKS cluster (use it in 'aws eks update-kubeconfig')."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint URL of the cluster."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group automatically created for the cluster."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "Name of the managed worker node group."
  value       = aws_eks_node_group.this.node_group_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA certificate used by kubectl to trust the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}
