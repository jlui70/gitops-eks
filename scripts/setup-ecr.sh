#!/bin/bash

# Script para criar repositórios ECR para os microserviços

set -e

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="794038226274"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       🐳 SETUP AMAZON ECR REPOSITORIES                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Lista de microserviços
SERVICES=(
    "ecommerce-ui"
    "product-catalog"
    "order-management"
    "product-inventory"
    "profile-management"
    "shipping-and-handling"
    "contact-support-team"
)

echo "📦 Criando repositórios ECR..."
echo ""

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="ecommerce/$SERVICE"
    
    echo "🔍 Verificando $REPO_NAME..."
    
    if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" 2>/dev/null; then
        echo "   ✅ $REPO_NAME já existe"
    else
        echo "   📦 Criando $REPO_NAME..."
        aws ecr create-repository \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        
        echo "   ✅ $REPO_NAME criado!"
    fi
    
    echo ""
done

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              ✅ ECR SETUP COMPLETED!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Repositórios criados:"
aws ecr describe-repositories --region "$AWS_REGION" | jq -r '.repositories[] | select(.repositoryName | startswith("ecommerce/")) | .repositoryUri'
echo ""
echo "🔐 Para fazer push de imagens:"
echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo ""
echo "📤 Exemplo de push:"
echo "   docker tag ecommerce-ui:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/ecommerce-ui:latest"
echo "   docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/ecommerce-ui:latest"
echo ""
