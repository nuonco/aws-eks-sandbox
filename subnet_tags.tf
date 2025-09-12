# ensure all of the relevant subnets are tagged for use by this cluster
# applied accross the board since these subnets are not guaranteed or expected
# to have these tags in place, but the tags are required.
# see the aws-cloudformation template for the VPC for the relevant subnet definitions
module "additional_subnet_tags" {
  source = "./subnet_tags"

  eks_cluster_name   = module.eks.cluster_name
  private_subnet_ids = local.subnets.private.ids
  public_subnet_ids  = local.subnets.public.ids
  depends_on         = [module.eks]
}
