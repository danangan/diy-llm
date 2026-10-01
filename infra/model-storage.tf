data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "models" {
  bucket        = var.app_name
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

resource "aws_iam_role" "service_role" {
  name               = "${var.app_name}"
  assume_role_policy = data.aws_iam_policy_document.models.json
}

data "aws_iam_policy_document" "service_role" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.models.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.models.arn}/*"]
  }
}

resource "aws_iam_role_policy" "service_role" {
  role   = aws_iam_role.service_role.id
  policy = data.aws_iam_policy_document.service_role.json
}

resource "aws_eks_pod_identity_association" "service_role" {
  cluster_name    = module.k8s_cluster.cluster_name
  namespace       = "default"
  service_account = "diy-llm"
  role_arn        = aws_iam_role.service_role.arn
}
