# S3 bucket that stores the Terraform state file.
resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name

  # Let 'terraform destroy' delete the bucket even though it still contains the
  # (versioned) state files — Terraform empties it first. Without this, destroy
  # fails with "BucketNotEmpty". Fine for a learning project; for a real,
  # long-lived state bucket you'd leave this off to prevent accidental deletion.
  force_destroy = true

  tags = {
    Name      = var.bucket_name
    Purpose   = "terraform-state"
    ManagedBy = "terraform"
  }
}

# Keep a full history of every state change (lets you roll back).
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the state file at rest (it can contain sensitive values).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Make sure the state bucket is never publicly accessible.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
