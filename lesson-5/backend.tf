# backend.tf — store Terraform state in S3, with DynamoDB for locking.
#
# ⚠️ BOOTSTRAP ORDER (first run only):
# The S3 bucket + DynamoDB table referenced below are CREATED by the s3_backend
# module in this same project, so they don't exist on the very first run. Do:
#   1) terraform init -backend=false   # start with LOCAL state
#   2) terraform apply                 # creates the bucket + DynamoDB table
#   3) terraform init -migrate-state   # move local state into S3 (answer "yes")
# After that, use terraform normally. See README.md for the full explanation.
#
# NOTE: a backend block cannot use variables, so the bucket name is a literal
# string here. It MUST match the bucket_name passed to the module in main.tf.

terraform {
  backend "s3" {
    bucket         = "my-microservice-lesson-5-tfstate-139214069645" # same UNIQUE name as in main.tf
    key            = "lesson-5/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
