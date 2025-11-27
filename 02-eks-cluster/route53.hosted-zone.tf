# CONFIGURAÇÃO DE DNS - OPCIONAL
# Esta configuração adiciona DNS customizado mas mantém o ALB original funcionando
# 
# Para ativar: 
#   1. Descomente os recursos abaixo
#   2. Execute: terraform apply
#   3. Configure os Name Servers no RegistroBR
#
# Para desativar e voltar ao estado da apresentação:
#   Execute: ./restore_presentation_config.sh

/*
# Route 53 Hosted Zone para o domínio
resource "aws_route53_zone" "this" {
  name = var.custom_domain

  tags = {
    Name        = "EKS DevOps Project Domain"
    Environment = "production" 
    Purpose     = "dns-automation"
  }
}
*/