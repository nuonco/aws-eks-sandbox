locals {
  kyverno = {
    namespace  = "kyverno"
    value_file = "${path.module}/values/kyverno/values.yaml"
    default_policies = [
      "${path.module}/values/kyverno/policies/restrict-binding-system-groups.yaml",
      "${path.module}/values/kyverno/policies/restrict-secret-role-verbs.yaml",
    ]
  }
}

// install kyverno
resource "helm_release" "kyverno" {
  namespace        = "kyverno"
  create_namespace = true

  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = "3.3.7" // TODO: make an input var?

  values = [
    file(local.kyverno.value_file),
  ]

  depends_on = [
    helm_release.metrics_server
  ]
}

resource "kubectl_manifest" "default_policies" {
  for_each  = toset(local.kyverno.default_policies)
  yaml_body = file(each.value)

  depends_on = [
    helm_release.kyverno
  ]
}
