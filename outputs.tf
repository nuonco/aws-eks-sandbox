output "account" {
  value = {
    id     = data.aws_caller_identity.current.account_id
    region = var.region
  }
  description = "A map of AWS account attributes: id, region."
}

output "cluster" {
  // NOTE: these are declared here -
  // https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest?tab=outputs
  value = {
    arn                        = module.eks.cluster_arn
    certificate_authority_data = module.eks.cluster_certificate_authority_data
    endpoint                   = module.eks.cluster_endpoint
    name                       = module.eks.cluster_name
    platform_version           = module.eks.cluster_platform_version
    status                     = module.eks.cluster_status
    oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
    oidc_provider_arn          = module.eks.oidc_provider_arn
    cluster_security_group_id  = module.eks.cluster_security_group_id
    node_security_group_id     = module.eks.node_security_group_id
  }
  description = "A map of EKS cluster attributes: arn, certificate_authority_data, endpoint, name, platform_version, status, oidc_issuer_url, oidc_provider_arn, cluster_security_group_id, node_security_group_id."
}

output "vpc" {
  value = {
    // NOTE: these are declared here -
    // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
    id   = data.aws_vpc.vpc.id
    arn  = data.aws_vpc.vpc.arn
    cidr = data.aws_vpc.vpc.cidr_block
    azs  = data.aws_availability_zones.available.names
    # replaces this next line - overall not necessary
    # azs  = data.aws_vpc.vpc.azs

    // ensure the data resource will actually hand us this
    private_subnet_cidr_blocks = values(data.aws_subnet.private)[*].cidr_block
    private_subnet_ids         = data.aws_subnets.private.ids

    public_subnet_cidr_blocks = values(data.aws_subnet.public)[*].cidr_block
    public_subnet_ids         = data.aws_subnets.public.ids
    # public_subnet_ids         = data.aws_subnet.public[each.key].id
    default_security_group_id = data.aws_security_group.default.id
  }
  description = "A map of vpc attributes: name, id, cidr, azs, private_subnet_cidr_blocks, private_subnet_ids, public_subnet_cidr_blocks, public_subnet_ids, default_security_group_id."
}

output "ecr" {
  value = {
    repository_url  = module.ecr.repository_url
    repository_arn  = module.ecr.repository_arn
    repository_name = var.nuon_id
    registry_id     = module.ecr.repository_registry_id
    registry_url    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  }
  description = "A map of ECR attributes: repository_url, repository_arn, repository_name, registry_id, registry_url."
}


# toggleables
output "nuon_dns" {
  value = {
    enabled         = local.nuon_dns.enabled,
    public_domain   = local.nuon_dns.enabled ? module.nuon_dns[0].public_domain : { zone_id : "", name : "", nameservers : tolist([""]) }
    internal_domain = local.nuon_dns.enabled ? module.nuon_dns[0].internal_domain : { zone_id : "", name : "", nameservers : tolist([""]) }
  }
}

output "alb_ingress_controller" {
  value = {
    enabled = local.enable_alb_ingress_controller
    id      = local.enable_alb_ingress_controller ? resource.helm_release.alb_ingress_controller[0].id : ""
  }
}

output "ingress_nginx" {
  value = {
    enabled = local.enable_ingress_nginx
    id      = local.enable_ingress_nginx ? resource.helm_release.ingress_nginx[0].id : ""
  }
}
