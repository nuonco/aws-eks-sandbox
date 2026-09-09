locals {
  cluster_name    = substr((var.cluster_name != "" ? var.cluster_name : var.nuon_id), 0, 38)
  cluster_version = var.cluster_version

  instance_types = [var.default_instance_type]
  ami_type       = var.ami_type
  min_size       = var.min_size
  max_size       = var.max_size
  desired_size   = var.desired_size

  // access entries
  // three roles in play: provision, deprovision, maintenance
  // this becomes the provision role
  default_access_entries = {
    "provision" = {
      principal_arn       = var.provision_iam_role_arn
      kubernetes_groups   = concat(["provision"], var.provision_role_eks_kubernetes_groups)
      policy_associations = var.provision_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
    "maintenance" = {
      principal_arn       = var.maintenance_iam_role_arn
      kubernetes_groups   = concat(["maintenance"], var.maintenance_role_eks_kubernetes_groups)
      policy_associations = var.maintenance_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
    "deprovision" = {
      principal_arn       = var.deprovision_iam_role_arn
      kubernetes_groups   = concat(["deprovision"], var.deprovision_role_eks_kubernetes_groups)
      policy_associations = var.deprovision_role_eks_access_entry_policy_associations,
      tags                = local.tags
    },
  }

  break_glass_access_entry = var.break_glass_iam_role_arn != "" ? {
    "break_glass" = {
      principal_arn       = var.break_glass_iam_role_arn
      kubernetes_groups   = concat(["break_glass"], var.break_glass_role_eks_kubernetes_groups)
      policy_associations = var.break_glass_role_eks_access_entry_policy_associations,
      tags                = local.tags
    }
  } : {}

  access_entries = merge(local.default_access_entries, local.break_glass_access_entry, var.additional_access_entry)
}

resource "aws_kms_key" "eks" {
  description = "Key for ${local.cluster_name} EKS cluster"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name                           = local.cluster_name
  cluster_version                        = local.cluster_version
  cluster_endpoint_private_access        = true
  cluster_endpoint_public_access         = var.cluster_endpoint_public_access
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days

  vpc_id     = data.aws_vpc.vpc.id
  subnet_ids = local.subnets.private.ids

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      most_recent = true
      preserve    = true

      # the cni creates secondary enis itself, so default_tags never reach them
      configuration_values = jsonencode({
        env = {
          ADDITIONAL_ENI_TAGS = jsonencode(local.tags)
        }
      })
    }
  }

  authentication_mode                      = "API_AND_CONFIG_MAP"
  access_entries                           = local.access_entries
  enable_cluster_creator_admin_permissions = false

  node_security_group_additional_rules = {}

  eks_managed_node_groups = {
    default = {
      instance_types = local.instance_types
      ami_type       = local.ami_type
      min_size       = local.min_size
      max_size       = local.max_size
      desired_size   = local.desired_size

      iam_role_additional_policies = {
        additional = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = local.tags
}

# TODO: revisit this access method
resource "aws_security_group_rule" "runner_cluster_access" {
  type                     = "ingress"
  description              = "Allow ingress traffic from runner."
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = data.aws_security_groups.runner.ids[0] # make this less brittle

  depends_on = [module.eks]
}

# eks doesn't propagate node group tags to the asg it creates
locals {
  node_group_asg_tags = merge([
    for name, ng in module.eks.eks_managed_node_groups : {
      for key, value in local.tags :
      "${name}|${key}" => {
        asg_name = one(ng.node_group_autoscaling_group_names)
        key      = key
        value    = value
      }
    }
  ]...)
}

resource "aws_autoscaling_group_tag" "node_group" {
  for_each = local.node_group_asg_tags

  autoscaling_group_name = each.value.asg_name

  tag {
    key                 = each.value.key
    value               = each.value.value
    propagate_at_launch = true
  }
}

# eks makes its own copy of the launch template and points the asg at that one
data "aws_autoscaling_group" "node_group" {
  for_each = module.eks.eks_managed_node_groups

  name = one(each.value.node_group_autoscaling_group_names)
}

locals {
  # managed node groups reference it through a mixed instances policy
  eks_managed_launch_template_ids = {
    for name, asg in data.aws_autoscaling_group.node_group : name =>
    try(asg.mixed_instances_policy[0].launch_template[0].launch_template_specification[0].launch_template_id, "") != ""
    ? asg.mixed_instances_policy[0].launch_template[0].launch_template_specification[0].launch_template_id
    : try(asg.launch_template[0].id, "")
  }
}

resource "aws_ec2_tag" "eks_managed_launch_template" {
  for_each = {
    for pair in setproduct(keys(local.eks_managed_launch_template_ids), keys(local.tags)) :
    "${pair[0]}|${pair[1]}" => {
      launch_template_id = local.eks_managed_launch_template_ids[pair[0]]
      key                = pair[1]
    }
  }

  resource_id = each.value.launch_template_id
  key         = each.value.key
  value       = local.tags[each.value.key]
}
