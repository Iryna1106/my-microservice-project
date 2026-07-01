# locals.tf — values worked out AUTOMATICALLY from your AWS account & region,
# so you don't have to type (or expose) them.

# Your AWS account ID — read from the credentials you ran `aws configure` with.
# This is how the ECR URL and the state-bucket name get YOUR account number
# without it being hard-coded anywhere.
data "aws_caller_identity" "current" {}

# The Availability Zones in the chosen region. We use the first three (one per
# subnet), so switching var.aws_region "just works" as long as the region has 3.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)

  # Globally-unique S3 bucket name for Terraform state. The account id suffix
  # keeps it unique to you.
  # ⚠️ This MUST match the literal 'bucket' value in backend.tf (which cannot use
  #    variables). If you change project_name or use a different account, update
  #    backend.tf to match.
  state_bucket_name = "my-microservice-${var.project_name}-tfstate-${local.account_id}"
  lock_table_name   = "terraform-locks-${var.project_name}"
}
