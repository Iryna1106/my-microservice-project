# DynamoDB table used by Terraform to LOCK the state while someone is applying
# changes, so two people can't corrupt it at the same time.
resource "aws_dynamodb_table" "locks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # pay only for what you use; no capacity planning
  hash_key     = "LockID"          # Terraform requires this exact attribute name

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = var.table_name
    Purpose   = "terraform-state-locking"
    ManagedBy = "terraform"
  }
}
