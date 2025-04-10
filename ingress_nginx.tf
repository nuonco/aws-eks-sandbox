resource "helm_release" "ingress_nginx" {
  count = local.enable_ingress_nginx ? 1 : 0

  namespace        = "nginx-ingress"
  create_namespace = true

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.1"
  timeout    = 600

  set {
    name  = "rbac.create"
    value = "true"
  }

  depends_on = [
    module.alb_controller_irsa,
    helm_release.alb_ingress_controller
  ]
}
