// Roles, RoleBindings, and Groups for IAM Roles
locals {
  groups = {
    maintenance = {
      role         = "${path.module}/values/k8s/maintenance_role.yaml"
      role_binding = "${path.module}/values/k8s/maintenance_rb.yaml"
    }
  }
}

resource "kubectl_manifest" "maintenance" {
  for_each  = toset([local.groups.maintenance.role, local.groups.maintenance.role_binding])
  yaml_body = file(each.value)

  depends_on = [
    module.eks,
    resource.null_resource.set_kubeconfig
  ]
}
