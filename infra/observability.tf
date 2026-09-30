resource "helm_release" "obstack" {
  name       = "obstack"
  repository = "oci://ghcr.io/danangan/charts"
  chart      = "obstack"
  version    = "0.3.0"
  timeout    = 900

  values = [
    file("${path.module}/helm-values/obstack.yaml"),
    yamlencode({
      ingress = {
        grafanaHost = var.grafana_dns.host
        annotations = {
          "alb.ingress.kubernetes.io/group.name"      = local.alb_group
          "alb.ingress.kubernetes.io/certificate-arn" = local.certificate_arns.grafana
        }
      }
    }),
    # GPU metrics: DCGM Exporter on the GPU nodes. The chart's default affinity
    # needs labels managed node groups don't set, so match the instance type.
    yamlencode({
      gpu = {
        enabled = true
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values   = [var.gpu_instance_type]
                }]
              }]
            }
          }
        }
      }
    }),
  ]

  depends_on = [module.k8s_cluster, aws_eks_node_group.obstack]
}

# A dedicated node for obstack, in one AZ so it's always in the same AZ as
# obstack's EBS volumes. Pods need the label and toleration set in
# helm-values/obstack.yaml.

data "aws_subnets" "obstack" {
  filter {
    name   = "vpc-id"
    values = [module.k8s_cluster.vpc_id]
  }
  filter {
    name   = "availability-zone"
    values = [var.obstack_availability_zone]
  }
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  depends_on = [module.k8s_cluster]
}

# The module's node security group, so these nodes and the module's can reach
# each other. The module doesn't output it, but tags it "<cluster>-node".
data "aws_security_group" "node" {
  vpc_id = module.k8s_cluster.vpc_id
  tags = {
    Name = "${var.cluster_name}-node"
  }
  depends_on = [module.k8s_cluster]
}

data "aws_iam_policy_document" "obstack_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "obstack_node" {
  name               = "${var.cluster_name}-obstack-node"
  assume_role_policy = data.aws_iam_policy_document.obstack_node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "obstack_node" {
  for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly", "AmazonEKS_CNI_Policy"])

  role       = aws_iam_role.obstack_node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

resource "aws_launch_template" "obstack" {
  name_prefix            = "${var.cluster_name}-obstack-"
  vpc_security_group_ids = [data.aws_security_group.node.id]

  # Lets pods reach the instance metadata service, like on the module's nodes
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

resource "aws_eks_node_group" "obstack" {
  cluster_name    = module.k8s_cluster.cluster_name
  node_group_name = "obstack"
  node_role_arn   = aws_iam_role.obstack_node.arn
  subnet_ids      = data.aws_subnets.obstack.ids
  ami_type        = "AL2023_ARM_64_STANDARD"
  instance_types  = [var.obstack_instance_type]

  scaling_config {
    min_size     = 0
    max_size     = 1
    desired_size = 1
  }

  launch_template {
    id      = aws_launch_template.obstack.id
    version = aws_launch_template.obstack.latest_version
  }

  labels = {
    workload = "obstack"
  }

  taint {
    key    = "dedicated"
    value  = "obstack"
    effect = "NO_SCHEDULE"
  }

  depends_on = [aws_iam_role_policy_attachment.obstack_node]
}
