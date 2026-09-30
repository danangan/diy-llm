locals {
  account_id      = data.aws_caller_identity.current.account_id
  eks_cluster_arn = "arn:aws:eks:${var.region}:${local.account_id}:cluster/${module.k8s_cluster.cluster_name}"
}

resource "aws_iam_user" "deploy" {
  name = "${var.app_name}-deploy"
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.models.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.models.arn}/*"]
  }
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [local.eks_cluster_arn]
  }
}

resource "aws_iam_user_policy" "deploy" {
  user   = aws_iam_user.deploy.name
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_eks_access_entry" "deploy" {
  cluster_name  = module.k8s_cluster.cluster_name
  principal_arn = aws_iam_user.deploy.arn
}

resource "aws_eks_access_policy_association" "deploy" {
  cluster_name  = module.k8s_cluster.cluster_name
  principal_arn = aws_iam_user.deploy.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.deploy]
}
