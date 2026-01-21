#!/bin/bash

# Script para criar IAM User para GitHub Actions
# EKS DevOps Project

set -e

echo "🔐 Setup IAM User para GitHub Actions"
echo "======================================"
echo ""

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Criar IAM User
echo "1️⃣ Criando IAM User: github-actions-eks..."
if aws iam get-user --user-name github-actions-eks >/dev/null 2>&1; then
    echo "   ⚠️  User já existe, pulando criação..."
else
    aws iam create-user --user-name github-actions-eks \
        --tags Key=Project,Value=GitOpsEKS Key=Purpose,Value=CICD
    echo "   ✅ User criado!"
fi
echo ""

# Criar IAM Policy
echo "2️⃣ Criando IAM Policy: GitHubActionsEKSPolicy..."

POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:AccessKubernetesApi"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

if aws iam get-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsEKSPolicy >/dev/null 2>&1; then
    echo "   ⚠️  Policy já existe, atualizando..."
    # Deletar versões antigas se necessário
    VERSIONS=$(aws iam list-policy-versions --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsEKSPolicy --query 'Versions[?!IsDefaultVersion].VersionId' --output text)
    for VERSION in $VERSIONS; do
        aws iam delete-policy-version --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsEKSPolicy --version-id $VERSION 2>/dev/null || true
    done
    
    # Criar nova versão
    aws iam create-policy-version \
        --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsEKSPolicy \
        --policy-document "$POLICY_DOC" \
        --set-as-default
    echo "   ✅ Policy atualizada!"
else
    aws iam create-policy \
        --policy-name GitHubActionsEKSPolicy \
        --policy-document "$POLICY_DOC" \
        --description "Policy for GitHub Actions to deploy to EKS"
    echo "   ✅ Policy criada!"
fi
echo ""

# Attach policy ao user
echo "3️⃣ Anexando policy ao user..."
aws iam attach-user-policy \
    --user-name github-actions-eks \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsEKSPolicy
echo "   ✅ Policy anexada!"
echo ""

# Criar Access Key
echo "4️⃣ Criando Access Keys..."
echo "   ⚠️  ATENÇÃO: Guarde estas credenciais em local seguro!"
echo ""

# Verificar se já existe access key
EXISTING_KEYS=$(aws iam list-access-keys --user-name github-actions-eks --query 'AccessKeyMetadata[].AccessKeyId' --output text)

if [ -n "$EXISTING_KEYS" ]; then
    echo "   ⚠️  Access keys existentes encontradas:"
    echo "   $EXISTING_KEYS"
    echo ""
    read -p "   Deseja criar nova access key? (S/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "   ⏭️  Pulando criação de access key"
        echo ""
        echo "📋 Use as credenciais existentes ou delete as antigas primeiro:"
        echo "   aws iam delete-access-key --user-name github-actions-eks --access-key-id <KEY_ID>"
        exit 0
    fi
fi

ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name github-actions-eks)
ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         🔑 CREDENCIAIS GITHUB ACTIONS                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  COPIE E GUARDE ESSAS CREDENCIAIS AGORA!"
echo "⚠️  Elas NÃO serão exibidas novamente!"
echo ""
echo "📋 Configure no GitHub:"
echo "   Repositório → Settings → Environments → production → Add secret"
echo ""
echo "AWS_ACCESS_KEY_ID:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$ACCESS_KEY_ID"
echo ""
echo "AWS_SECRET_ACCESS_KEY:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$SECRET_ACCESS_KEY"
echo ""
echo "AWS_ACCOUNT_ID:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$AWS_ACCOUNT_ID"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         📝 PRÓXIMOS PASSOS                                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Acesse: https://github.com/<SEU-USUARIO>/gitops-eks/settings/environments"
echo ""
echo "2. Crie environment 'production' (se não existir)"
echo ""
echo "3. Adicione os 3 secrets acima"
echo ""
echo "4. Configure aws-auth ConfigMap no EKS:"
echo "   kubectl edit configmap aws-auth -n kube-system"
echo ""
echo "   Adicione na seção mapUsers:"
echo "   - userarn: arn:aws:iam::${AWS_ACCOUNT_ID}:user/github-actions-eks"
echo "     username: github-actions-eks"
echo "     groups:"
echo "       - system:masters"
echo ""
echo "   OU execute: ./scripts/update-aws-auth.sh"
echo ""
echo "5. Teste GitHub Actions:"
echo "   Actions → CD - Deploy to EKS → Run workflow"
echo ""
echo "✅ Setup concluído!"
echo ""
