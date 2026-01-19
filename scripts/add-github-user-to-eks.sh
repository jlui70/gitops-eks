#!/bin/bash

# Script para adicionar usuário GitHub Actions ao aws-auth ConfigMap
# Permite que GitHub Actions faça deploy no cluster EKS

set -e

echo "🔐 Adicionando usuário github-actions-eks ao cluster EKS..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

kubectl patch configmap aws-auth -n kube-system --patch "
data:
  mapUsers: |
    - userarn: arn:aws:iam::${ACCOUNT_ID}:user/github-actions-eks
      username: github-actions-eks
      groups:
      - system:masters
"

echo "✅ Usuário github-actions-eks adicionado com sucesso!"
echo ""
echo "Para verificar:"
echo "  kubectl get configmap aws-auth -n kube-system -o yaml"
