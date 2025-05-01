data "aws_secretsmanager_secret" "secrets" {
  arn = var.arn
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

resource "kubectl_manifest" "secret" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      namespace = var.namespace
      name      = var.name
      labels = {
        "nuon.co/managed-by" = "terraform"
      }
    }
    spec = {
      data = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)
    }
  })
}
