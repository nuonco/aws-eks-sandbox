module "nuon-aws-eks-sandbox" {
  source = "./.."

  vpc_id                   = var.vpc_id
  provision_iam_role_arn   = var.provision_iam_role_arn
  maintenance_iam_role_arn = var.maintenance_iam_role_arn
  deprovision_iam_role_arn = var.deprovision_iam_role_arn

  provision_role_eks_access_entry_policy_associations   = var.provision_role_eks_access_entry_policy_associations
  maintenance_role_eks_access_entry_policy_associations = var.maintenance_role_eks_access_entry_policy_associations
  deprovision_role_eks_access_entry_policy_associations = var.deprovision_role_eks_access_entry_policy_associations

  additional_access_entry = var.additional_access_entry

  kyverno_policies = var.kyverno_policies

  # cluster
  cluster_version       = var.cluster_version
  cluster_name          = var.cluster_name
  min_size              = var.min_size
  max_size              = var.max_size
  desired_size          = var.desired_size
  default_instance_type = var.default_instance_type

  # toggleable components
  enable_alb_ingress_controller = var.enable_alb_ingress_controller
  enable_nuon_dns               = var.enable_nuon_dns
  enable_ingress_nginx          = var.enable_ingress_nginx

  # provided by nuon
  nuon_id              = var.nuon_id
  internal_root_domain = var.internal_root_domain
  public_root_domain   = var.public_root_domain
  region               = var.region
  tags                 = var.tags
}
