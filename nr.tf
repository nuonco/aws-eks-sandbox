resource "null_resource" "set_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
  }
  depends_on = [module.eks]
}
