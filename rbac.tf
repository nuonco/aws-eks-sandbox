// Roles, RoleBindings, and Groups for IAM Roles
locals {
  groups = {
    maintenance = {
      default_role = "${path.module}/values/k8s/maintenance_role.yaml"
      role_binding = "${path.module}/values/k8s/maintenance_rb.yaml"

      labels = length(var.maintenance_cluster_role_rules_override) > 0 ? { "nuon.co/source" : "customer-defined" } : { "nuon.co/source" : "sandbox-defaults" }
    }
  }
}

resource "kubectl_manifest" "maintenance" {
  yaml_body = yamlencode({
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "name"   = "maintenance"
      "labels" = local.groups.maintenance.labels
    }
    "rules" = length(var.maintenance_cluster_role_rules_override) > 0 ? var.maintenance_cluster_role_rules_override : yamldecode(file(local.groups.maintenance.default_role)).rules
  })
  depends_on = [
    module.eks,
    resource.null_resource.set_kubeconfig
  ]
}

resource "kubectl_manifest" "maintenance_role_binding" {
  yaml_body = file(local.groups.maintenance.role_binding)
  depends_on = [
    module.eks,
    resource.null_resource.set_kubeconfig
  ]
}
