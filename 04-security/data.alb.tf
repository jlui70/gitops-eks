# Data source para obter informações do ALB criado pelo ALB Controller
# NOTA: Durante destroy, o ALB pode já ter sido deletado via kubectl delete ingress
# Por isso usamos count para tornar este data source opcional
data "aws_lb" "eks_alb" {
  count = 0  # Desabilitado - ALB é deletado via kubectl antes do terraform destroy
  
  tags = {
    "ingress.k8s.aws/stack" = "default/eks-devopsproject-ingress"
  }
}