data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["eks-devopsproject-vpc"]
  }
}
