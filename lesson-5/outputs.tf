# outputs.tf — surfaces the most useful values from all three modules.

# --- S3 backend ---
output "state_bucket_name" {
  description = "S3 bucket that stores Terraform state."
  value       = module.s3_backend.s3_bucket_name
}

output "state_bucket_url" {
  description = "URL (regional domain name) of the state S3 bucket."
  value       = module.s3_backend.s3_bucket_url
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
  description = "URL of the ECR repository (docker push/pull target)."
  value       = module.ecr.repository_url
}
