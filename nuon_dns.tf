module "nuon_dns" {
  count = local.nuon_dns.enabled ? 1 : 0

  providers = {
    kubectl = kubectl.main
    helm    = helm.main
  }

  source = "./nuon_dns"

  internal_root_domain  = var.internal_root_domain
  public_root_domain    = var.public_root_domain
  eks_cluster_name      = module.eks.cluster_name
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  region                = var.region
  vpc_id                = data.aws_vpc.vpc.id
  nuon_id               = var.nuon_id
  tags                  = var.tags

  enable_ingress_nginx          = local.nuon_dns.enable_ingress_nginx
  enable_cert_manager           = local.nuon_dns.enable_cert_manager
  enable_alb_ingress_controller = local.nuon_dns.enable_alb_ingress_controller
  enable_external_dns           = local.nuon_dns.enable_external_dns

  depends_on = [
    module.eks,
    resource.aws_security_group_rule.runner_cluster_access,
  ]
}
