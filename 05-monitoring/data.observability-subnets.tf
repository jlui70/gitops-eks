data "aws_subnets" "observability" {
  filter {
    name   = "tag:Project"
    values = ["eks-devopsproject"]
  }

  filter {
    name   = "tag:Purpose"
    values = ["observability"]
  }
}
