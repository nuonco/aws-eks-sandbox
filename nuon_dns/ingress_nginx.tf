locals {
  ingress_nginx = {
    namespace = "ingress-nginx"
    name      = "ingress-nginx"
  }
}

resource "helm_release" "ingress_nginx" {
  namespace        = local.ingress_nginx.namespace
  create_namespace = true

  name       = local.ingress_nginx.name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.1"
  timeout    = 600

  set {
    name  = "rbac.create"
    value = "true"
  }

  values = [
    yamlencode({
      tolerations : [
        {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NoSchedule"
        },
        {
          key : "CriticalAddonsOnly"
          value : "true"
          effect : "NoSchedule"
        },
      ]
    })
  ]

  depends_on = [
    helm_release.alb_ingress_controller
  ]
}
