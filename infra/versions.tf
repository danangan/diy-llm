terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "diy-llm"
      ManagedBy = "terraform"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.k8s_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.k8s_cluster.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.k8s_cluster.cluster_name, "--region", var.region]
    }
  }
}
