# The Virtual Private Cloud — your isolated private network on AWS.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Internet Gateway — the "front door" to the internet for the public subnets.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Public subnets — instances here can get public IPs and reach the internet.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"
    Tier = "public"
    # Marks these (public) subnets so an internet-facing Kubernetes
    # "LoadBalancer" Service places its AWS load balancer here.
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets — hidden from the internet; reach out only via the NAT Gateway.
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.vpc_name}-private-${count.index + 1}"
    Tier = "private"
    # Marks these (private) subnets for INTERNAL load balancers (not used by
    # this lesson, but it is the correct counterpart to the public tag above).
    "kubernetes.io/role/internal-elb" = "1"
  }
}
