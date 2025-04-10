locals {
  aws_alb_controller = {
    service_account_name = "aws-load-balancer-controller"
  }
}

module "alb_controller_irsa" {
  count = local.enable_alb_ingress_controller ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "alb-controller-${var.nuon_id}"

  create_role                            = true
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    k8s = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["alb-ingress:${local.aws_alb_controller.service_account_name}"]
    }
  }

  tags = local.tags
}

resource "helm_release" "alb_ingress_controller" {
  count = local.enable_alb_ingress_controller ? 1 : 0

  namespace        = "alb-ingress"
  create_namespace = true

  name       = "alb-ingress-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.12.0"

  set {
    name  = "enableCertManager"
    value = "apply"
  }

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = local.aws_alb_controller.service_account_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa[0].iam_role_arn
  }

  set { // we only set this one tag in case any of the others (in local.tags) conflict.
    name  = "defaultTags.nuon_install_id"
    value = var.nuon_id
  }

  set { // we only set this one tag in case any of the others (in local.tags) conflict.
    name  = "defaultTags.created_by"
    value = "alb-ingress-controller"
  }

  depends_on = [
    module.alb_controller_irsa,
    module.eks,
  ]
}
