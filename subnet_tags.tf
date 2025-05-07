module "additional_subnet_tags" {
  # only create if the cluster name does not equal the nuon id
  count = module.eks.cluster_name == var.nuon_id ? 0 : 1

  source = "./subnet_tags"

  eks_cluster_name   = module.eks.cluster_name
  private_subnet_ids = local.subnets.private.ids
  public_subnet_ids  = local.subnets.public.ids
  depends_on         = [module.eks]
}
