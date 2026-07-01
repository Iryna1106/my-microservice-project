# outputs.tf — surfaces the most useful values from all the modules.
# After 'terraform apply', run 'terraform output' to see them.

# --- S3 backend ---
output "state_bucket_name" {
  description = "S3 bucket that stores Terraform state."
  value       = module.s3_backend.s3_bucket_name
}

output "dynamodb_lock_table" {
  description = "DynamoDB table used for state locking."
  value       = module.s3_backend.dynamodb_table_name
}

# --- VPC ---
output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

# --- ECR ---
output "ecr_repository_url" {
  description = "URL of the ECR repository (your docker/Kaniko push target)."
  value       = module.ecr.repository_url
}

# --- EKS ---
output "eks_cluster_name" {
  description = "Name of the EKS cluster (use in 'aws eks update-kubeconfig')."
  value       = module.eks.cluster_name
}

# Handy ready-to-copy command to point kubectl at the new cluster.
output "kubeconfig_command" {
  description = "Run this to configure kubectl for the cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# --- Jenkins (CI) ---
output "jenkins_url" {
  description = "Command to fetch the Jenkins UI address (the AWS load balancer)."
  value       = module.jenkins.jenkins_url_command
}

output "jenkins_admin_password_command" {
  description = "Run this to print the auto-generated Jenkins 'admin' password."
  value       = module.jenkins.admin_password_command
}

# --- Argo CD (CD) ---
output "argocd_url" {
  description = "Command to fetch the Argo CD UI address (the AWS load balancer)."
  value       = module.argo_cd.argocd_url_command
}

output "argocd_admin_password_command" {
  description = "Run this to print the auto-generated Argo CD 'admin' password."
  value       = module.argo_cd.admin_password_command
}
