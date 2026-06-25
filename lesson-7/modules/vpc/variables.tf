variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "CIDR blocks for the public subnets."
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for the private subnets."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones to spread the subnets across."
  type        = list(string)
}

variable "vpc_name" {
  description = "Name prefix used for tagging the VPC resources."
  type        = string
  default     = "lesson-5-vpc"
}
