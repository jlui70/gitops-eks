# Data source para obter as subnets privadas onde o cluster EKS está rodando
data "aws_subnets" "eks_private" {
  filter {
    name   = "tag:Project"
    values = ["eks-devopsproject"]
  }

  filter {
    name   = "tag:Purpose"
    values = ["eks-devopsproject-cluster"]
  }
}