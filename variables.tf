locals {
  enable_alb_ingress_controller = contains(["1", "true"], var.enable_alb_ingress_controller)
  enable_ingress_nginx          = contains(["1", "true"], var.enable_ingress_nginx) && local.enable_alb_ingress_controller
  # nuon dns
  enable_nuon_dns = contains(["1", "true"], var.enable_nuon_dns)
  nuon_dns = {
    enabled              = local.enable_nuon_dns && local.enable_alb_ingress_controller
    internal_root_domain = var.internal_root_domain
    public_root_domain   = var.public_root_domain
  }

  # tags for all of the resources
  tags = merge(
    var.tags,
    {
      "install.nuon.co/id"  = var.nuon_id
      "sanbox.nuon.co/name" = "aws-eks"
    },
    var.additional_tags,
  )

  roles = {
    provision_iam_role_name   = split("/", var.provision_iam_role_arn)[length(split("/", var.provision_iam_role_arn)) - 1]
    deprovision_iam_role_name = split("/", var.deprovision_iam_role_arn)[length(split("/", var.deprovision_iam_role_arn)) - 1]
    maintenance_iam_role_name = split("/", var.maintenance_iam_role_arn)[length(split("/", var.maintenance_iam_role_arn)) - 1]
  }
}

#
# from cloudformation
#

variable "vpc_id" {
  type        = string
  description = "The ID of the AWS VPC to provision the sandbox in."
}

variable "maintenance_iam_role_arn" {
  type        = string
  description = "The provision IAM Role ARN"
}

variable "provision_iam_role_arn" {
  type        = string
  description = "The maintenance IAM Role ARN"
}

variable "deprovision_iam_role_arn" {
  type        = string
  description = "The deprovision IAM Role ARN"
}

#
# from configs
#

# policies and roles
variable "provision_role_eks_kubernetes_groups" {
  type        = list(any)
  description = "List of Kubernetes Groups to add this role to."
  default     = []
}

variable "provision_role_eks_access_entry_policy_associations" {
  type        = map(any)
  description = "EKS Cluster Access Entry Policy Associations for provision role."
  default = {
    cluster_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
    eks_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
  }
}

variable "maintenance_role_eks_kubernetes_groups" {
  type        = list(any)
  description = "List of Kubernetes Groups to add this role to."
  default     = []
}

variable "maintenance_role_eks_access_entry_policy_associations" {
  type        = map(any)
  description = "EKS Cluster Access Entry Policy Associations for maintenance role."
  default = {
    cluster_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
    eks_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
  }
}

variable "deprovision_role_eks_kubernetes_groups" {
  type        = list(any)
  description = "List of Kubernetes Groups to add this role to."
  default     = []
}

variable "deprovision_role_eks_access_entry_policy_associations" {
  type        = map(any)
  description = "EKS Cluster Access Entry Policy Associations for deprovision role."
  default = {
    cluster_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
    eks_admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
      access_scope = {
        type = "cluster"
      }
    }
  }
}

variable "additional_access_entry" {
  type        = map(any)
  description = "A single access entry. Useful when providing access to an additional role."
  default     = {}
  # default = {
  #   "admin-access-for-org" = {
  #     principal_arn     = var.admin_access_role,
  #     kubernetes_groups = []
  #     policy_associations = {
  #       cluster_admin = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #         }
  #       }
  #       eks_admin = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #         }
  #       }
  #     }
  #   }
  # }
}


variable "kyverno_policies" {
  type        = list(map(any))
  description = "A list of kyverno policies."
  default     = []
}

#
# install inputs
#

# cluster details
variable "cluster_version" {
  type        = string
  description = "The Kubernetes version to use for the EKS cluster."
  default     = "1.32"
}


variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster. If not provided, the install ID will be used by default."
  default     = ""
}

variable "min_size" {
  type        = number
  default     = 2
  description = "The minimum number of nodes in the managed node group."
}

variable "max_size" {
  type        = number
  default     = 5
  description = "The maximum number of nodes in the managed node group."
}

variable "desired_size" {
  type        = number
  default     = 3
  description = "The desired number of nodes in the managed node group."
}

variable "default_instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "The EC2 instance type to use for the EKS cluster's default node group."
}


variable "additional_tags" {
  type        = map(any)
  description = "Extra tags to append to the default tags that will be added to install resources."
  default     = {}
}

#
# toggle-able components
#

# Nuon DNS
variable "enable_nuon_dns" {
  type        = string
  default     = "false"
  description = "Whether or not the cluster should use a nuon-provided nuon.run domain. Controls the cert-manager-issuer and the route_53_zone."
}

variable "enable_alb_ingress_controller" {
  type        = string
  default     = "false"
  description = "Whether or not the ALB Ingress helm chart should be installed."
}

variable "enable_ingress_nginx" {
  type        = string
  default     = "false"
  description = "Whether or not the Ingress-Nginx helm chart should be installed."
}


# toggle-able helm charts
# TODO

#
# set by nuon
#
#
variable "nuon_id" {
  type        = string
  description = "The nuon id for this install. Used for naming purposes."
}

variable "region" {
  type        = string
  description = "The region to launch the cluster in."
}

# DNS
variable "public_root_domain" {
  type        = string
  description = "The public root domain."
}

# NOTE: if you would like to create an internal load balancer, with TLS, you will have to use the public domain.
variable "internal_root_domain" {
  type        = string
  description = "The internal root domain."
}

variable "tags" {
  type        = map(any)
  description = "List of custom tags to add to the install resources. Used for taxonomic purposes."
}
