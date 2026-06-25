# outputs.tf — surfaces the most useful values from all four modules.
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

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

# --- ECR ---
output "ecr_repository_url" {
  description = "URL of the ECR repository (your docker push/pull target)."
  value       = module.ecr.repository_url
}

# --- EKS ---
output "eks_cluster_name" {
  description = "Name of the EKS cluster (use in 'aws eks update-kubeconfig')."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

# Handy ready-to-copy command to point kubectl at the new cluster.
output "kubeconfig_command" {
  description = "Run this to configure kubectl for the cluster."
  value       = "aws eks update-kubeconfig --region us-west-2 --name ${module.eks.cluster_name}"
}
