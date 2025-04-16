module "nuon_dns" {
  count = local.nuon_dns.enabled ? 1 : 0

  source = "./nuon_dns"

  internal_root_domain  = var.internal_root_domain
  public_root_domain    = var.public_root_domain
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  region                = var.region
  vpc_id                = data.aws_vpc.vpc.id
  nuon_id               = var.nuon_id
  tags                  = var.tags

  depends_on = [
    module.eks,
    helm_release.metrics_server
  ]
}
