locals {
  alb_group = "diy-llm"

  sites = {
    grafana = var.grafana_dns
  }
  certificate_arns = {
    for name, site in local.sites :
    name => "arn:aws:acm:${var.region}:${local.account_id}:certificate/${site.certificate_id}"
  }
}

data "aws_route53_zone" "sites" {
  for_each = local.sites
  name     = each.value.zone
}

data "aws_lb" "shared" {
  tags = {
    "elbv2.k8s.aws/cluster" = module.k8s_cluster.cluster_name
    "ingress.k8s.aws/stack" = local.alb_group
  }
  depends_on = [helm_release.obstack]
}

resource "aws_route53_record" "sites" {
  for_each = local.sites

  zone_id = data.aws_route53_zone.sites[each.key].zone_id
  name    = each.value.host
  type    = "A"

  alias {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = false
  }
}
