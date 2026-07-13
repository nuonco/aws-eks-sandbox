# tag subnet for use by this cluster
resource "aws_ec2_tag" "private_subnets_cluster_tags" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.eks_cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnets_cluster_tags" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.eks_cluster_name}"
  value       = "shared"
}

# ELB role tags: required for the AWS cloud-controller-manager to auto-discover
# subnets when placing load balancers for Service type=LoadBalancer (e.g. the
# ingress-nginx controller). Without these the LB never provisions and helm
# waits forever on the pending Service.
resource "aws_ec2_tag" "public_subnets_elb_role" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnets_internal_elb_role" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
