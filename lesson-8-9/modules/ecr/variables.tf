variable "ecr_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities automatically when they are pushed."
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "MUTABLE allows overwriting image tags; IMMUTABLE forbids it."
  type        = string
  default     = "MUTABLE"
}
