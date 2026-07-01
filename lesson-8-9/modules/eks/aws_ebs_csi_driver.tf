# =============================================================================
#  EBS CSI DRIVER — gives Kubernetes the ability to create real AWS disks
#  (EBS volumes) on demand for pods that ask for storage.
#
#  Why we need it in lessons 8–9: the Jenkins controller keeps its data (jobs,
#  config, plugins) on a PersistentVolumeClaim (a "disk request"). On a fresh
#  modern EKS cluster nothing fulfils that request until this driver is
#  installed — the claim would sit "Pending" forever and Jenkins never starts.
#
#  Analogy: Kubernetes can ASK for a disk, but the EBS CSI driver is the
#  "warehouse worker" that actually goes and fetches one from AWS.
#
#  The driver's controller must prove to AWS that it is allowed to create disks.
#  It does that with IRSA (IAM Roles for Service Accounts): a Kubernetes service
#  account is linked to an AWS IAM role through the cluster's OIDC provider.
# =============================================================================

# -----------------------------------------------------------------------------
#  1. OIDC PROVIDER — the trust bridge between the cluster and AWS IAM.
#     It lets AWS believe "this pod really is who it claims to be", so a pod's
#     service account can borrow an IAM role. (Also reusable for other IRSA
#     roles later, e.g. if you switch Kaniko from node creds to IRSA.)
# -----------------------------------------------------------------------------

# Fetch the TLS certificate of the cluster's OIDC endpoint to get its thumbprint
# (a fingerprint AWS uses to trust the endpoint).
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = {
    Name      = "${var.cluster_name}-oidc"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
#  2. IAM ROLE for the EBS CSI driver's controller.
#     The trust policy says: "only the 'ebs-csi-controller-sa' service account
#     in the kube-system namespace may wear this badge."
# -----------------------------------------------------------------------------

# The bare OIDC host (issuer URL without the leading "https://"), used to build
# the trust-policy condition keys below.
locals {
  oidc_host = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    # Lock the role to exactly one service account.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = {
    Name      = "${var.cluster_name}-ebs-csi-role"
    ManagedBy = "terraform"
  }
}

# The AWS-managed permissions the driver needs (create/attach/delete volumes).
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# -----------------------------------------------------------------------------
#  3. THE ADDON — installs the actual driver into the cluster as a managed EKS
#     add-on, wired to the IAM role above.
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  # If the add-on already exists (or a config differs), let Terraform win.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Install only after the worker nodes exist, so the driver's controller pods
  # have somewhere to run.
  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.ebs_csi,
  ]

  tags = {
    Name      = "${var.cluster_name}-ebs-csi"
    ManagedBy = "terraform"
  }
}
