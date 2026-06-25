# =============================================================================
#  EKS = Amazon's managed Kubernetes. Kubernetes is a "robot manager" that runs
#  your containers, restarts them if they crash, and scales them up/down.
#
#  An EKS cluster has two parts:
#    1. The CONTROL PLANE (the brain) — managed by AWS for you.
#    2. The WORKER NODES (EC2 machines) — where your Django pods actually run.
#
#  Each part needs its own IAM role (an "ID badge" that grants AWS permissions).
# =============================================================================

# -----------------------------------------------------------------------------
#  1. IAM ROLE FOR THE CONTROL PLANE (the cluster's brain)
# -----------------------------------------------------------------------------

# This policy document says: "the EKS service is allowed to wear this badge."
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

# The standard AWS-managed permissions the control plane needs to operate.
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------------------------------------------------------
#  2. THE EKS CLUSTER (control plane)
# -----------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  # Run the cluster inside our EXISTING VPC. We pass BOTH public and private
  # subnets: nodes live in private subnets, and the public ones are available
  # for the internet-facing LoadBalancer Service.
  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_public_access  = true # so you can reach the cluster with kubectl from your laptop
    endpoint_private_access = true # nodes talk to the control plane privately
  }

  # Modern EKS access control. "bootstrap_cluster_creator_admin_permissions"
  # automatically gives the person who runs `terraform apply` full kubectl
  # admin rights — so you can use kubectl right away with no extra setup.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name      = var.cluster_name
    ManagedBy = "terraform"
  }

  # Don't try to build the cluster before its permissions exist.
  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

# -----------------------------------------------------------------------------
#  3. IAM ROLE FOR THE WORKER NODES (the EC2 machines)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Lets nodes register with the cluster and run pods.
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Lets the pod networking (VPC CNI) hand out IP addresses to pods.
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# IMPORTANT: this is what lets the nodes PULL your Django image from ECR.
# Without it, pods get stuck with an "ErrImagePull" error.
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -----------------------------------------------------------------------------
#  4. MANAGED NODE GROUP (the worker EC2 machines that run your pods)
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn

  # Nodes run in the PRIVATE subnets (hidden from the internet — best practice).
  subnet_ids     = var.private_subnet_ids
  instance_types = var.node_instance_types
  ami_type       = var.node_ami_type

  # How many worker machines to run (this is the NODE count, separate from the
  # POD count that the HPA scales).
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # During an upgrade, take at most 1 node offline at a time.
  update_config {
    max_unavailable = 1
  }

  tags = {
    Name      = "${var.cluster_name}-nodes"
    ManagedBy = "terraform"
  }

  # Don't create nodes before their permissions exist.
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}
