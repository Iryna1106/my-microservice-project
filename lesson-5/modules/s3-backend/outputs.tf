output "s3_bucket_name" {
  description = "Name of the S3 state bucket."
  value       = aws_s3_bucket.state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 state bucket."
  value       = aws_s3_bucket.state.arn
}

output "s3_bucket_url" {
  description = "Regional domain name (URL) of the S3 state bucket."
  value       = aws_s3_bucket.state.bucket_regional_domain_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB lock table."
  value       = aws_dynamodb_table.locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB lock table."
  value       = aws_dynamodb_table.locks.arn
}
