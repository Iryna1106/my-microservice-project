# backend.tf — store Terraform state in S3, with DynamoDB for locking.
#
# ⚠️ BOOTSTRAP ORDER (first run only):
# The S3 bucket + DynamoDB table referenced below are CREATED by the s3_backend
# module in this same project, so they don't exist on the very first run.
# ALSO: the Jenkins/Argo CD Helm releases can only be installed AFTER the EKS
# cluster exists, so we build the cluster first with a targeted apply. Do:
#   1) mv backend.tf backend.tf.bak        # start with LOCAL state
#   2) terraform init
#   3) terraform apply -target=module.eks  # build VPC + cluster first (~15 min)
#   4) terraform apply                     # S3 bucket, ECR, Jenkins, Argo CD
#   5) mv backend.tf.bak backend.tf
#   6) terraform init -migrate-state       # move local state into S3 (answer "yes")
# After that, use terraform normally. See README.md for the full explanation.
#
# ⚠️ THIS FILE IS THE ONE EXCEPTION to the "everything is a variable" rule.
# Terraform reads the backend block BEFORE variables exist, so it CANNOT use
# variables or locals — the values below must be plain literal strings.
#
# 👉 If you deploy in a different AWS account, region, or with a different
#    project_name, EDIT the four lines marked "← EDIT" so they match locals.tf:
#      bucket  = "my-microservice-<project_name>-tfstate-<your-account-id>"
#      table   = "terraform-locks-<project_name>"
#      region  = "<aws_region>"

terraform {
  backend "s3" {
    bucket         = "my-microservice-lesson-8-9-tfstate-139214069645" # ← EDIT (must match locals.state_bucket_name)
    key            = "lesson-8-9/terraform.tfstate"                    # ← EDIT (folder = project_name)
    region         = "us-west-2"                                       # ← EDIT (must match var.aws_region)
    dynamodb_table = "terraform-locks-lesson-8-9"                      # ← EDIT (must match locals.lock_table_name)
    encrypt        = true
  }
}
