# https://github.com/danangan/terraform-aws-k8s
module "k8s_cluster" {
  source  = "danangan/k8s/aws"
  version = "~> 1.6"

  aws_region              = var.region
  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = var.availability_zone_count

  enable_auto_mode = false

  cpu_instance_type           = var.cpu_instance_type
  cpu_node_group_min_size     = 0
  cpu_node_group_desired_size = var.cpu_instance_desired_size
  cpu_node_group_max_size     = 2

  gpu_instance_type           = var.gpu_instance_type
  gpu_node_group_min_size     = 0
  gpu_node_group_desired_size = var.gpu_instance_desired_size
  gpu_node_group_max_size     = 1
  gpu_node_disk_size          = 100
}
