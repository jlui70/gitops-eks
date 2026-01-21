#!/bin/bash

# Script para limpar recursos órfãos que sobreviveram ao destroy
# Versão: 1.0
# Data: 19 de Janeiro de 2026
# Uso: Quando o destroy-all.sh falha em remover todos os recursos

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🧹 LIMPEZA DE RECURSOS ÓRFÃOS                               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="terraform"
REGION="us-east-1"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ══════════════════════════════════════════════════════════════════════
# PASSO 1: VERIFICAR RECURSOS ÓRFÃOS
# ══════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════"
echo "📊 PASSO 1: Verificando recursos órfãos na AWS"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Verificar EKS Cluster
echo "🔍 Verificando EKS Cluster..."
CLUSTER_NAME="eks-devopsproject-cluster"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region $REGION --profile $PROFILE &>/dev/null; then
    echo -e "  ${RED}❌ Cluster EKS ainda existe: $CLUSTER_NAME${NC}"
    HAS_CLUSTER=true
else
    echo -e "  ${GREEN}✅ Cluster EKS não encontrado${NC}"
    HAS_CLUSTER=false
fi
echo ""

# Verificar VPC
echo "🔍 Verificando VPC..."
VPC_NAME="eks-devopsproject-vpc"
VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    --profile $PROFILE \
    --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo -e "  ${RED}❌ VPC ainda existe: $VPC_ID ($VPC_NAME)${NC}"
    HAS_VPC=true
    
    # Listar recursos dentro da VPC
    echo "     📋 Recursos na VPC:"
    
    # Subnets
    SUBNET_COUNT=$(aws ec2 describe-subnets \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'length(Subnets)' \
        --output text 2>/dev/null || echo "0")
    echo "        - Subnets: $SUBNET_COUNT"
    
    # NAT Gateways
    NAT_COUNT=$(aws ec2 describe-nat-gateways \
        --region $REGION \
        --profile $PROFILE \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
        --query 'length(NatGateways)' \
        --output text 2>/dev/null || echo "0")
    echo "        - NAT Gateways: $NAT_COUNT"
    
    # Internet Gateway
    IGW_COUNT=$(aws ec2 describe-internet-gateways \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'length(InternetGateways)' \
        --output text 2>/dev/null || echo "0")
    echo "        - Internet Gateways: $IGW_COUNT"
    
    # Route Tables (excluindo a main)
    RT_COUNT=$(aws ec2 describe-route-tables \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'length(RouteTables[?Associations[0].Main==`false`])' \
        --output text 2>/dev/null || echo "0")
    echo "        - Route Tables (custom): $RT_COUNT"
    
    # Security Groups (excluindo default)
    SG_COUNT=$(aws ec2 describe-security-groups \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'length(SecurityGroups[?GroupName!=`default`])' \
        --output text 2>/dev/null || echo "0")
    echo "        - Security Groups: $SG_COUNT"
    
    # ENIs (Elastic Network Interfaces)
    ENI_COUNT=$(aws ec2 describe-network-interfaces \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'length(NetworkInterfaces)' \
        --output text 2>/dev/null || echo "0")
    echo "        - Network Interfaces: $ENI_COUNT"
else
    echo -e "  ${GREEN}✅ VPC não encontrada${NC}"
    HAS_VPC=false
fi
echo ""

# Verificar Elastic IPs
echo "🔍 Verificando Elastic IPs..."
EIP_COUNT=$(aws ec2 describe-addresses \
    --region $REGION \
    --profile $PROFILE \
    --filters "Name=tag:Project,Values=eks-devopsproject" \
    --query 'length(Addresses)' \
    --output text 2>/dev/null || echo "0")

if [ "$EIP_COUNT" -gt 0 ]; then
    echo -e "  ${RED}❌ Elastic IPs ainda existem: $EIP_COUNT${NC}"
    HAS_EIP=true
else
    echo -e "  ${GREEN}✅ Elastic IPs não encontrados${NC}"
    HAS_EIP=false
fi
echo ""

# Verificar ECR Repositories
echo "🔍 Verificando ECR Repositories..."
ECR_REPOS=$(aws ecr describe-repositories \
    --region $REGION \
    --profile $PROFILE \
    --query 'repositories[?starts_with(repositoryName, `ecommerce/`)].repositoryName' \
    --output text 2>/dev/null || echo "")

if [ -n "$ECR_REPOS" ]; then
    ECR_COUNT=$(echo "$ECR_REPOS" | wc -w)
    echo -e "  ${RED}❌ ECR Repositories ainda existem: $ECR_COUNT${NC}"
    for repo in $ECR_REPOS; do
        echo "        - $repo"
    done
    HAS_ECR=true
else
    echo -e "  ${GREEN}✅ ECR Repositories não encontrados${NC}"
    HAS_ECR=false
fi
echo ""

# Verificar S3 Buckets
echo "🔍 Verificando S3 Bucket do backend..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE 2>/dev/null)
BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"

if aws s3 ls "s3://$BUCKET_NAME" --profile $PROFILE &>/dev/null; then
    echo -e "  ${RED}❌ S3 Bucket ainda existe: $BUCKET_NAME${NC}"
    OBJECT_COUNT=$(aws s3 ls "s3://$BUCKET_NAME" --recursive --profile $PROFILE | wc -l)
    echo "        - Objetos no bucket: $OBJECT_COUNT"
    HAS_S3=true
else
    echo -e "  ${GREEN}✅ S3 Bucket não encontrado${NC}"
    HAS_S3=false
fi
echo ""

# ══════════════════════════════════════════════════════════════════════
# RESUMO E AÇÃO
# ══════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════"
echo "📊 RESUMO DE RECURSOS ÓRFÃOS"
echo "═══════════════════════════════════════════════════════════════════"

FOUND_ORPHANS=false

if [ "$HAS_CLUSTER" = true ]; then
    echo -e "${RED}❌ EKS Cluster${NC}"
    FOUND_ORPHANS=true
fi

if [ "$HAS_VPC" = true ]; then
    echo -e "${RED}❌ Stack 01 - Networking (VPC + recursos)${NC}"
    FOUND_ORPHANS=true
fi

if [ "$HAS_EIP" = true ]; then
    echo -e "${RED}❌ Elastic IPs${NC}"
    FOUND_ORPHANS=true
fi

if [ "$HAS_ECR" = true ]; then
    echo -e "${RED}❌ ECR Repositories${NC}"
    FOUND_ORPHANS=true
fi

if [ "$HAS_S3" = true ]; then
    echo -e "${RED}❌ S3 Bucket (backend)${NC}"
    FOUND_ORPHANS=true
fi

if [ "$FOUND_ORPHANS" = false ]; then
    echo -e "${GREEN}✅ Nenhum recurso órfão encontrado!${NC}"
    echo ""
    exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  PASSO 2: Deletar recursos órfãos"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo -e "${YELLOW}⚠️  ATENÇÃO: Este script irá FORÇAR a deleção dos recursos órfãos!${NC}"
echo ""
read -p "Continuar com a limpeza? (s/N): " confirm

if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# DELETAR ECR REPOSITORIES
# ══════════════════════════════════════════════════════════════════════

if [ "$HAS_ECR" = true ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Deletando ECR Repositories"
    echo "═══════════════════════════════════════════════════════════════════"
    
    for repo in $ECR_REPOS; do
        echo "  🗑️  Deletando: $repo"
        aws ecr delete-repository \
            --repository-name "$repo" \
            --region $REGION \
            --force \
            --profile $PROFILE 2>/dev/null && \
            echo -e "     ${GREEN}✅ Deletado${NC}" || \
            echo -e "     ${RED}❌ Erro ao deletar${NC}"
    done
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════
# DELETAR EKS CLUSTER (se ainda existir)
# ══════════════════════════════════════════════════════════════════════

if [ "$HAS_CLUSTER" = true ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Deletando EKS Cluster"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  ⚠️  Isso pode levar 5-10 minutos..."
    
    # Deletar node groups primeiro
    echo "  🔍 Verificando node groups..."
    NODE_GROUPS=$(aws eks list-nodegroups \
        --cluster-name "$CLUSTER_NAME" \
        --region $REGION \
        --profile $PROFILE \
        --query 'nodegroups' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$NODE_GROUPS" ]; then
        for ng in $NODE_GROUPS; do
            echo "     🗑️  Deletando node group: $ng"
            aws eks delete-nodegroup \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$ng" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        echo "     ⏳ Aguardando node groups serem deletados..."
        aws eks wait nodegroup-deleted \
            --cluster-name "$CLUSTER_NAME" \
            --nodegroup-name "$ng" \
            --region $REGION \
            --profile $PROFILE 2>/dev/null || true
    fi
    
    # Deletar cluster
    echo "  🗑️  Deletando cluster: $CLUSTER_NAME"
    aws eks delete-cluster \
        --name "$CLUSTER_NAME" \
        --region $REGION \
        --profile $PROFILE 2>/dev/null && \
        echo -e "     ${GREEN}✅ Cluster deletado${NC}" || \
        echo -e "     ${RED}❌ Erro ao deletar cluster${NC}"
    
    echo "  ⏳ Aguardando cluster ser deletado..."
    aws eks wait cluster-deleted \
        --name "$CLUSTER_NAME" \
        --region $REGION \
        --profile $PROFILE 2>/dev/null || true
    
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════
# DELETAR STACK 01 - NETWORKING VIA TERRAFORM
# ══════════════════════════════════════════════════════════════════════

if [ "$HAS_VPC" = true ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Deletando Stack 01 - Networking (via Terraform)"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/01-networking"
    
    # Verificar se há state
    if terraform state list &>/dev/null 2>&1; then
        echo "  📋 Recursos no Terraform state:"
        terraform state list
        echo ""
        
        echo "  🗑️  Executando terraform destroy..."
        terraform destroy -auto-approve || {
            echo ""
            echo -e "  ${YELLOW}⚠️  Terraform destroy falhou. Tentando limpeza manual...${NC}"
            echo ""
            
            # Forçar remoção do state lock se existir
            if [ -f ".terraform/terraform.tfstate" ]; then
                rm -f .terraform/terraform.tfstate
            fi
            
            # Tentar novamente
            terraform destroy -auto-approve || {
                echo -e "  ${RED}❌ Terraform destroy falhou novamente${NC}"
                echo "  💡 Você pode tentar deletar a VPC manualmente via console AWS"
            }
        }
    else
        echo -e "  ${YELLOW}⚠️  Nenhum state do Terraform encontrado${NC}"
        echo "  💡 Tentando deleção manual via AWS CLI..."
        echo ""
        
        # MÉTODO MANUAL: Deletar recursos na ordem correta
        
        # 1. Deletar NAT Gateways
        echo "  🗑️  Deletando NAT Gateways..."
        NAT_IDS=$(aws ec2 describe-nat-gateways \
            --region $REGION \
            --profile $PROFILE \
            --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
            --query 'NatGateways[].NatGatewayId' \
            --output text 2>/dev/null || echo "")
        
        for nat_id in $NAT_IDS; do
            echo "     → Deletando NAT Gateway: $nat_id"
            aws ec2 delete-nat-gateway \
                --nat-gateway-id "$nat_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        if [ -n "$NAT_IDS" ]; then
            echo "     ⏳ Aguardando NAT Gateways serem deletados (60s)..."
            sleep 60
        fi
        
        # 2. Liberar e deletar Elastic IPs
        echo "  🗑️  Deletando Elastic IPs..."
        EIP_ALLOC_IDS=$(aws ec2 describe-addresses \
            --region $REGION \
            --profile $PROFILE \
            --filters "Name=domain,Values=vpc" \
            --query 'Addresses[].AllocationId' \
            --output text 2>/dev/null || echo "")
        
        for eip_id in $EIP_ALLOC_IDS; do
            echo "     → Liberando Elastic IP: $eip_id"
            aws ec2 release-address \
                --allocation-id "$eip_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        # 3. Deletar Network Interfaces órfãos
        echo "  🗑️  Deletando Network Interfaces..."
        ENI_IDS=$(aws ec2 describe-network-interfaces \
            --region $REGION \
            --profile $PROFILE \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' \
            --output text 2>/dev/null || echo "")
        
        for eni_id in $ENI_IDS; do
            echo "     → Deletando ENI: $eni_id"
            aws ec2 delete-network-interface \
                --network-interface-id "$eni_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        # 4. Deletar Security Groups (exceto default)
        echo "  🗑️  Deletando Security Groups..."
        SG_IDS=$(aws ec2 describe-security-groups \
            --region $REGION \
            --profile $PROFILE \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
            --output text 2>/dev/null || echo "")
        
        # Primeiro remover regras que referenciam outros SGs
        for sg_id in $SG_IDS; do
            echo "     → Removendo regras do SG: $sg_id"
            aws ec2 revoke-security-group-ingress \
                --group-id "$sg_id" \
                --region $REGION \
                --profile $PROFILE \
                --source-group "$sg_id" 2>/dev/null || true
        done
        
        # Depois deletar os SGs
        for sg_id in $SG_IDS; do
            echo "     → Deletando SG: $sg_id"
            aws ec2 delete-security-group \
                --group-id "$sg_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        # 5. Desassociar e deletar Route Tables
        echo "  🗑️  Deletando Route Tables..."
        RT_IDS=$(aws ec2 describe-route-tables \
            --region $REGION \
            --profile $PROFILE \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
            --output text 2>/dev/null || echo "")
        
        for rt_id in $RT_IDS; do
            # Desassociar subnets
            ASSOC_IDS=$(aws ec2 describe-route-tables \
                --region $REGION \
                --profile $PROFILE \
                --route-table-ids "$rt_id" \
                --query 'RouteTables[].Associations[?!Main].RouteTableAssociationId' \
                --output text 2>/dev/null || echo "")
            
            for assoc_id in $ASSOC_IDS; do
                echo "     → Desassociando: $assoc_id"
                aws ec2 disassociate-route-table \
                    --association-id "$assoc_id" \
                    --region $REGION \
                    --profile $PROFILE 2>/dev/null || true
            done
            
            echo "     → Deletando Route Table: $rt_id"
            aws ec2 delete-route-table \
                --route-table-id "$rt_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        # 6. Deletar Internet Gateway
        echo "  🗑️  Deletando Internet Gateway..."
        IGW_IDS=$(aws ec2 describe-internet-gateways \
            --region $REGION \
            --profile $PROFILE \
            --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
            --query 'InternetGateways[].InternetGatewayId' \
            --output text 2>/dev/null || echo "")
        
        for igw_id in $IGW_IDS; do
            echo "     → Desanexando IGW: $igw_id"
            aws ec2 detach-internet-gateway \
                --internet-gateway-id "$igw_id" \
                --vpc-id "$VPC_ID" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
            
            echo "     → Deletando IGW: $igw_id"
            aws ec2 delete-internet-gateway \
                --internet-gateway-id "$igw_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        # 7. Deletar Subnets
        echo "  🗑️  Deletando Subnets..."
        SUBNET_IDS=$(aws ec2 describe-subnets \
            --region $REGION \
            --profile $PROFILE \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'Subnets[].SubnetId' \
            --output text 2>/dev/null || echo "")
        
        for subnet_id in $SUBNET_IDS; do
            echo "     → Deletando Subnet: $subnet_id"
            aws ec2 delete-subnet \
                --subnet-id "$subnet_id" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
        done
        
        # 8. Deletar VPC
        echo "  🗑️  Deletando VPC: $VPC_ID"
        sleep 5  # Aguardar propagação
        aws ec2 delete-vpc \
            --vpc-id "$VPC_ID" \
            --region $REGION \
            --profile $PROFILE 2>/dev/null && \
            echo -e "     ${GREEN}✅ VPC deletada${NC}" || \
            echo -e "     ${RED}❌ Erro ao deletar VPC (pode ter recursos dependentes)${NC}"
    fi
    
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════
# DELETAR S3 BUCKET DO BACKEND
# ══════════════════════════════════════════════════════════════════════

if [ "$HAS_S3" = true ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Deletando S3 Bucket do Backend"
    echo "═══════════════════════════════════════════════════════════════════"
    
    echo "  🧹 Esvaziando bucket: $BUCKET_NAME"
    aws s3 rm "s3://$BUCKET_NAME" --recursive --profile $PROFILE 2>/dev/null || true
    
    # Remover versões antigas
    echo "  🧹 Removendo versões antigas..."
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile $PROFILE \
        --output json \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null | \
    aws s3api delete-objects \
        --bucket "$BUCKET_NAME" \
        --profile $PROFILE \
        --delete file:///dev/stdin 2>/dev/null || true
    
    # Remover delete markers
    echo "  🧹 Removendo delete markers..."
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile $PROFILE \
        --output json \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null | \
    aws s3api delete-objects \
        --bucket "$BUCKET_NAME" \
        --profile $PROFILE \
        --delete file:///dev/stdin 2>/dev/null || true
    
    echo "  🗑️  Deletando bucket..."
    aws s3 rb "s3://$BUCKET_NAME" --profile $PROFILE 2>/dev/null && \
        echo -e "     ${GREEN}✅ Bucket deletado${NC}" || \
        echo -e "     ${RED}❌ Erro ao deletar bucket${NC}"
    
    # Deletar DynamoDB Table
    echo "  🗑️  Deletando DynamoDB table..."
    TABLE_NAME="eks-devopsproject-state-lock-table"
    aws dynamodb delete-table \
        --table-name "$TABLE_NAME" \
        --region $REGION \
        --profile $PROFILE 2>/dev/null && \
        echo -e "     ${GREEN}✅ DynamoDB table deletada${NC}" || \
        echo -e "     ${RED}❌ Erro ao deletar table (pode não existir)${NC}"
    
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════
# FINALIZAÇÃO
# ══════════════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ LIMPEZA DE RECURSOS ÓRFÃOS CONCLUÍDA!           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Verificando se ainda existem recursos..."
echo ""

# Verificação final
bash "$SCRIPT_DIR/cleanup-orphaned-resources.sh" 2>/dev/null || true

echo ""
echo "💡 PRÓXIMOS PASSOS:"
echo ""
echo "1. Se ainda existirem recursos, verifique o console AWS:"
echo "   - VPC: https://console.aws.amazon.com/vpc"
echo "   - EKS: https://console.aws.amazon.com/eks"
echo "   - ECR: https://console.aws.amazon.com/ecr"
echo "   - S3: https://console.aws.amazon.com/s3"
echo ""
echo "2. Para recriar a infraestrutura do zero:"
echo "   ./scripts/rebuild-all.sh"
echo ""
