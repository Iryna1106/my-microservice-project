# Look up the current AWS account ID (used to scope the repository policy).
data "aws_caller_identity" "current" {}

# The ECR repository where Docker images are stored.
resource "aws_ecr_repository" "this" {
  name                 = var.ecr_name
  image_tag_mutability = var.image_tag_mutability

  # Let 'terraform destroy' delete the repository even if it still holds images
  # (otherwise destroy fails with "RepositoryNotEmptyException"). Fine for a demo.
  force_delete = true

  # Automatically scan images for security vulnerabilities on push.
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Encrypt stored images at rest with server-side AES256 encryption
  # (same protection style as the S3 state bucket in s3.tf).
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name      = var.ecr_name
    ManagedBy = "terraform"
  }
}

# Lifecycle policy: keep only the 10 most recent images to save storage cost.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Access policy: allow push/pull only from within THIS AWS account.
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPullFromThisAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}
