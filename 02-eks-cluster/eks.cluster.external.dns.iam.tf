# EXTERNAL DNS IAM - OPCIONAL
# Comentado para manter configuração da apresentação
/*
# IAM Role para External DNS
resource "aws_iam_role" "external_dns" {
  name = "external-dns-irsa-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.kubernetes.arn
      }
      Condition = {
        StringEquals = {
          "${local.eks_oidc_url}:aud" = "sts.amazonaws.com"
          "${local.eks_oidc_url}:sub" = "system:serviceaccount:external-dns:external-dns"
        }
      }
    }]
    Version = "2012-10-17"
  })
}

# IAM Policy para External DNS
resource "aws_iam_policy" "external_dns" {
  name        = "AllowExternalDNSUpdates"
  description = "IAM policy for AWS External DNS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = ["arn:aws:route53:::hostedzone/*"],
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ],
        Resource = ["*"],
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns.arn
  role       = aws_iam_role.external_dns.name
}
*/