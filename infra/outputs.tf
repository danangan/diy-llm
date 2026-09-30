output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.k8s_cluster.cluster_name
}


output "model_bucket" {
  value = aws_s3_bucket.models.bucket
}

output "deployment_user_name" {
  description = "IAM user the CI/CD pipeline logs in as"
  value       = aws_iam_user.deploy.name
}

output "grafana_url" {
  value = "https://${var.grafana_dns.host}"
}

output "grafana_password_command" {
  value = "kubectl -n default get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d"
}
