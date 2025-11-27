# Associação do WAF Web ACL com o Application Load Balancer
# NOTA: WAF association comentada pois o ALB é deletado via kubectl (não via Terraform)
# Durante destroy, o comando 'kubectl delete ingress' remove o ALB antes do terraform destroy
# Se ativar esta associação, você receberá erro "LoadBalancerNotFound" no destroy
# Para aplicar WAF ao ALB, use anotações no Ingress YAML ou associe manualmente via AWS Console

# resource "aws_wafv2_web_acl_association" "eks_alb" {
#   resource_arn = data.aws_lb.eks_alb[0].arn
#   web_acl_arn  = aws_wafv2_web_acl.eks_waf.arn
# }