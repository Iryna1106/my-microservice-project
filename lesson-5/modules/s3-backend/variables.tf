variable "bucket_name" {
  description = "Globally-unique name of the S3 bucket for Terraform state."
  type        = string
}

variable "table_name" {
  description = "Name of the DynamoDB table for state locking."
  type        = string
  default     = "terraform-locks"
}
