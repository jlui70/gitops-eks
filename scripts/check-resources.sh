#!/bin/bash

# Script para verificar recursos AWS ativos
# Versão: 1.1 - Usa profile padrão ou especificado
# Data: 19 de Janeiro de 2026

REGION="us-east-1"

# Permitir especificar profile via argumento
if [ -n "$1" ]; then
    PROFILE_ARG="--profile $1"
    echo "🔐 Usando AWS Profile: $1"
else
    PROFILE_ARG=""
    echo "🔐 Usando AWS Profile padrão"
fi

# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_ARG --query Account --output text 2>/dev/null)

echo "📊 Account ID: $ACCOUNT_ID"
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🔍 VERIFICANDO RECURSOS AWS                                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar EKS Cluster
echo "🔍 EKS Cluster:"
CLUSTER_NAME="eks-devopsproject-cluster"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region $REGION $PROFILE_ARG &>/dev/null; then
    STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region $REGION $PROFILE_ARG --query 'cluster.status' --output text)
    echo "   ❌ Cluster existe: $CLUSTER_NAME (Status: $STATUS)"
else
    echo "   ✅ Cluster não encontrado"
fi
echo ""

# Verificar VPC
echo "🔍 VPC:"
VPC_NAME="eks-devopsproject-vpc"
VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    $PROFILE_ARG \
    --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "   ❌ VPC existe: $VPC_ID"
    echo ""
    echo "   📋 Recursos na VPC:"
    
    # Subnets
    SUBNETS=$(aws ec2 describe-subnets \
        --region $REGION \
        $PROFILE_ARG \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null || echo "")
    SUBNET_COUNT=$(echo "$SUBNETS" | wc -w)
    echo "      → Subnets: $SUBNET_COUNT"
    
    # NAT Gateways
    NAT_GWS=$(aws ec2 describe-nat-gateways \
        --region $REGION \
        $PROFILE_ARG \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
        --query 'NatGateways[].NatGatewayId' \
        --output text 2>/dev/null || echo "")
    NAT_COUNT=$(echo "$NAT_GWS" | wc -w)
    echo "      → NAT Gateways: $NAT_COUNT"
    if [ "$NAT_COUNT" -gt 0 ]; then
        for nat in $NAT_GWS; do
            STATE=$(aws ec2 describe-nat-gateways --nat-gateway-ids $nat --region $REGION $PROFILE_ARG --query 'NatGateways[0].State' --output text)
            echo "         - $nat ($STATE)"
        done
    fi
    
    # Internet Gateway
    IGW=$(aws ec2 describe-internet-gateways \
        --region $REGION \
        $PROFILE_ARG \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[].InternetGatewayId' \
        --output text 2>/dev/null || echo "")
    IGW_COUNT=$(echo "$IGW" | wc -w)
    echo "      → Internet Gateways: $IGW_COUNT"
    
    # Security Groups
    SG_COUNT=$(aws ec2 describe-security-groups \
        --region $REGION \
        $PROFILE_ARG \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'length(SecurityGroups[?GroupName!=`default`])' \
        --output text 2>/dev/null || echo "0")
    echo "      → Security Groups (custom): $SG_COUNT"
    
    # Network Interfaces
    ENI_COUNT=$(aws ec2 describe-network-interfaces \
        --region $REGION \
        $PROFILE_ARG \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'length(NetworkInterfaces)' \
        --output text 2>/dev/null || echo "0")
    echo "      → Network Interfaces: $ENI_COUNT"
else
    echo "   ✅ VPC não encontrada"
fi
echo ""

# Verificar Elastic IPs
echo "🔍 Elastic IPs:"
EIPS=$(aws ec2 describe-addresses \
    --region $REGION \
    $PROFILE_ARG \
    --query 'Addresses[].{IP:PublicIp,ID:AllocationId,Assoc:AssociationId}' \
    --output text 2>/dev/null || echo "")

if [ -n "$EIPS" ]; then
    EIP_COUNT=$(echo "$EIPS" | wc -l)
    echo "   ❌ Elastic IPs ativos: $EIP_COUNT"
    echo "$EIPS" | while read ip id assoc; do
        if [ -z "$assoc" ] || [ "$assoc" == "None" ]; then
            echo "      → $ip ($id) - NÃO ASSOCIADO"
        else
            echo "      → $ip ($id) - Associado"
        fi
    done
else
    echo "   ✅ Nenhum Elastic IP encontrado"
fi
echo ""

# Verificar ECR Repositories
echo "🔍 ECR Repositories:"
ECR_REPOS=$(aws ecr describe-repositories \
    --region $REGION \
    $PROFILE_ARG \
    --query 'repositories[].repositoryName' \
    --output text 2>/dev/null || echo "")

if [ -n "$ECR_REPOS" ]; then
    ECR_COUNT=$(echo "$ECR_REPOS" | wc -w)
    echo "   ❌ Repositories ativos: $ECR_COUNT"
    for repo in $ECR_REPOS; do
        IMAGE_COUNT=$(aws ecr describe-images \
            --repository-name "$repo" \
            --region $REGION \
            $PROFILE_ARG \
            --query 'length(imageDetails)' \
            --output text 2>/dev/null || echo "0")
        echo "      → $repo ($IMAGE_COUNT imagens)"
    done
else
    echo "   ✅ Nenhum repository encontrado"
fi
echo ""

# Verificar S3 Buckets
echo "🔍 S3 Buckets:"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text $PROFILE_ARG 2>/dev/null)
BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"

if aws s3 ls "s3://$BUCKET_NAME" $PROFILE_ARG &>/dev/null; then
    OBJECT_COUNT=$(aws s3 ls "s3://$BUCKET_NAME" --recursive $PROFILE_ARG 2>/dev/null | wc -l)
    BUCKET_SIZE=$(aws s3 ls "s3://$BUCKET_NAME" --recursive $PROFILE_ARG 2>/dev/null | awk '{sum+=$3} END {print sum/1024/1024}')
    echo "   ❌ Bucket existe: $BUCKET_NAME"
    echo "      → Objetos: $OBJECT_COUNT"
    echo "      → Tamanho: ${BUCKET_SIZE:-0} MB"
else
    echo "   ✅ Bucket não encontrado"
fi
echo ""

# Verificar DynamoDB
echo "🔍 DynamoDB Tables:"
TABLE_NAME="eks-devopsproject-state-lock-table"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region $REGION $PROFILE_ARG &>/dev/null; then
    STATUS=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --region $REGION $PROFILE_ARG --query 'Table.TableStatus' --output text)
    echo "   ❌ Table existe: $TABLE_NAME (Status: $STATUS)"
else
    echo "   ✅ Table não encontrada"
fi
echo ""

# Verificar Load Balancers
echo "🔍 Load Balancers:"
ALB_COUNT=$(aws elbv2 describe-load-balancers \
    --region $REGION \
    $PROFILE_ARG \
    --query 'length(LoadBalancers)' \
    --output text 2>/dev/null || echo "0")

if [ "$ALB_COUNT" -gt 0 ]; then
    echo "   ❌ Load Balancers ativos: $ALB_COUNT"
    aws elbv2 describe-load-balancers \
        --region $REGION \
        $PROFILE_ARG \
        --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code]' \
        --output text 2>/dev/null | while read name type state; do
        echo "      → $name ($type) - $state"
    done
else
    echo "   ✅ Nenhum Load Balancer encontrado"
fi
echo ""

# Verificar IAM Roles órfãos
echo "🔍 IAM Roles (EKS):"
IAM_ROLES=(
    "eks-devopsproject-cluster-role"
    "eks-devopsproject-node-group-role"
    "aws-load-balancer-controller"
    "external-dns-irsa-role"
    "AmazonEKS_EFS_CSI_DriverRole"
)

FOUND_ROLES=0
for role in "${IAM_ROLES[@]}"; do
    if aws iam get-role --role-name "$role" $PROFILE_ARG &>/dev/null; then
        echo "   ❌ Role existe: $role"
        FOUND_ROLES=$((FOUND_ROLES + 1))
    fi
done

if [ $FOUND_ROLES -eq 0 ]; then
    echo "   ✅ Nenhuma role órfã encontrada"
fi
echo ""

# Verificar IAM User GitHub Actions
echo "🔍 IAM Users:"
if aws iam get-user --user-name github-actions-eks $PROFILE_ARG &>/dev/null; then
    echo "   ❌ User existe: github-actions-eks"
else
    echo "   ✅ User github-actions-eks não encontrado"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              VERIFICAÇÃO COMPLETA                                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "💡 Para deletar recursos órfãos:"
echo "   ./scripts/cleanup-orphaned-resources.sh"
echo ""
