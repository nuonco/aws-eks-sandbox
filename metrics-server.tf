resource "helm_release" "metrics_server" {
  namespace        = "metrics-server"
  create_namespace = true

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.8.2"

  provider = helm.main

  depends_on = [
    module.eks,
    resource.aws_security_group_rule.runner_cluster_access,
  ]
}
