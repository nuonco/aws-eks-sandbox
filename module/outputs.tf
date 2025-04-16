output "account" {
  value = module.nuon-aws-eks-sandbox.account
}

output "cluster" {
  value = module.nuon-aws-eks-sandbox.cluster
}

output "vpc" {
  value = module.nuon-aws-eks-sandbox.vpc
}

output "ecr" {
  value = module.nuon-aws-eks-sandbox.ecr
}

output "nuon_dns" {
  value = module.nuon-aws-eks-sandbox.nuon_dns
}

output "alb_ingress_controller" {
  value = module.nuon-aws-eks-sandbox.alb_ingress_controller
}

output "ingress_nginx" {
  value = module.nuon-aws-eks-sandbox.ingress_nginx
}
