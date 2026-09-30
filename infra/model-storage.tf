data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "models" {
  bucket        = "${var.app_name}-models"
  force_destroy = true
}

data "aws_route_tables" "route_table" {
  vpc_id     = module.k8s_cluster.vpc_id
  depends_on = [module.k8s_cluster]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = module.k8s_cluster.vpc_id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = data.aws_route_tables.route_table.ids
}

data "aws_iam_policy_document" "models" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_runtime" {
  name               = "${var.app_name}-runtime"
  assume_role_policy = data.aws_iam_policy_document.models.json
}

data "aws_iam_policy_document" "app_runtime" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.models.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.models.arn}/*"]
  }
}

resource "aws_iam_role_policy" "app_runtime" {
  role   = aws_iam_role.app_runtime.id
  policy = data.aws_iam_policy_document.app_runtime.json
}

resource "aws_eks_pod_identity_association" "app_runtime" {
  cluster_name    = module.k8s_cluster.cluster_name
  namespace       = "default"
  service_account = "llm-runtime"
  role_arn        = aws_iam_role.app_runtime.arn
}
