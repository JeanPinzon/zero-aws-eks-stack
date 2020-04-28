
# Data sources for EKS IAM
data "aws_caller_identity" "current" {}

# @TODO - sort out creating only a single user but multiple roles per env

# Create KubernetesAdmin role for aws-iam-authenticator
resource "aws_iam_role" "kubernetes_admin_role" {
  name               = "${var.project}-kubernetes-admin-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assumerole_root_policy.json
  description        = "Kubernetes administrator role (for AWS EKS auth)"
}

# Trust relationship to limit access to the k8s admin serviceaccount
data "aws_iam_policy_document" "assumerole_root_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Allow the CI user to assume this role
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_user.ci_user.arn]
    }
  }
}

resource "aws_iam_user_policy_attachment" "circleci_ecr_access" {
  user       = data.aws_iam_user.ci_user.user_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}


# Allow the CI user to list and describe clusters
data "aws_iam_policy_document" "eks_list_and_describe" {
  statement {
    actions = [
      "eks:ListUpdates",
      "eks:ListClusters",
      "eks:DescribeUpdate",
      "eks:DescribeCluster",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_list_and_describe_policy" {
  name   = "${var.project}_eks_list_and_describe"
  policy = data.aws_iam_policy_document.eks_list_and_describe.json
}

resource "aws_iam_user_policy_attachment" "ci_user_list_and_describe_policy" {
  user       = data.aws_iam_user.ci_user.user_name
  policy_arn = aws_iam_policy.eks_list_and_describe_policy.arn
}

# Allow the CI user read/write access to the frontend assets bucket
data "aws_iam_policy_document" "read_write_s3_policy" {
  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = formatlist("arn:aws:s3:::%s", var.s3_hosting_buckets)
  }

  statement {
    actions = [
      "s3:*Object",
    ]

    resources = formatlist("arn:aws:s3:::%s/*", var.s3_hosting_buckets)
  }
}

resource "aws_iam_policy" "read_write_s3_policy" {
  name   = "${var.project}_ci_s3_policy"
  policy = data.aws_iam_policy_document.read_write_s3_policy.json
}

resource "aws_iam_user_policy_attachment" "ci_s3_policy" {
  user       = data.aws_iam_user.ci_user.user_name
  policy_arn = aws_iam_policy.read_write_s3_policy.arn
}