# Data source para buscar a Hosted Zone do Route 53
# Comentado até ativar a Route 53 Hosted Zone
/*
data "aws_route53_zone" "this" {
  name = var.custom_domain
  
  depends_on = [aws_route53_zone.this]
}
*/