#!/bin/bash

# Script para adicionar permissões ECR ao usuário github-actions-eks

set -e

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_NAME="github-actions-eks"
POLICY_NAME="GitHubActionsECRPolicy"

echo "🔧 Atualizando permissões para GitHub Actions..."
echo "Account: $AWS_ACCOUNT_ID"
echo "User: $USER_NAME"
echo ""

# Criar política para ECR
echo "📝 Criando política ECR..."
cat > /tmp/ecr-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:CreateRepository",
        "ecr:DescribeImages",
        "ecr:StartImageScan",
        "ecr:ListImages"
      ],
      "Resource": "arn:aws:ecr:*:${AWS_ACCOUNT_ID}:repository/ecommerce/*"
    }
  ]
}
EOF

# Verificar se a política já existe
if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" 2>/dev/null; then
  echo "⚠️  Política ${POLICY_NAME} já existe. Atualizando..."
  
  # Deletar versões antigas se necessário
  VERSIONS=$(aws iam list-policy-versions --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)
  for version in $VERSIONS; do
    echo "  Deletando versão antiga: $version"
    aws iam delete-policy-version --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" --version-id "$version"
  done
  
  # Criar nova versão
  aws iam create-policy-version \
    --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" \
    --policy-document file:///tmp/ecr-policy.json \
    --set-as-default
  
  echo "✅ Política atualizada!"
else
  echo "📦 Criando nova política..."
  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document file:///tmp/ecr-policy.json \
    --description "Permissions for GitHub Actions to access ECR"
  
  echo "✅ Política criada!"
fi

# Anexar política ao usuário
echo ""
echo "🔗 Anexando política ao usuário ${USER_NAME}..."
if aws iam attach-user-policy \
  --user-name "${USER_NAME}" \
  --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" 2>/dev/null; then
  echo "✅ Política anexada com sucesso!"
else
  echo "⚠️  Política já estava anexada ao usuário"
fi

# Listar políticas do usuário
echo ""
echo "📋 Políticas atuais do usuário ${USER_NAME}:"
aws iam list-attached-user-policies --user-name "${USER_NAME}" --query 'AttachedPolicies[].PolicyName' --output table

echo ""
echo "✅ Atualização concluída!"
echo ""
echo "💡 Agora você pode rodar o CI novamente no GitHub Actions"
