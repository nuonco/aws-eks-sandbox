module "nuon_dns" {
  count = local.nuon_dns.enabled ? 1 : 0

  source = "./nuon_dns"

  internal_root_domain  = var.internal_root_domain
  public_root_domain    = var.public_root_domain
  eks_cluster_name      = module.eks.cluster_name
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  region                = var.region
  vpc_id                = data.aws_vpc.vpc.id
  nuon_id               = var.nuon_id
  tags                  = var.tags

  providers = {
    helm       = helm
    kubectl    = kubectl
    kubernetes = kubernetes
  }

  depends_on = [
    module.eks,
    resource.null_resource.set_kubeconfig,
  ]
}
