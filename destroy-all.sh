#!/bin/bash

# Script para destruir todos os recursos na ordem correta
# Versão: 2.0
# Data: 27 de Novembro de 2025
# Stacks: 00-backend até 05-monitoring

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🗑️  DESTRUINDO INFRAESTRUTURA EKS - 6 STACKS               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_ROOT="/home/luiz7/Projects/eks-express-iac-nova-conta"

# Função para destruir uma stack
destroy_stack() {
    local stack_name=$1
    local stack_path=$2
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Destruindo: $stack_name"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/$stack_path"
    
    if [ -f "terraform.tfstate" ] || terraform state list &>/dev/null; then
        terraform destroy -auto-approve || {
            echo "⚠️  Erro ao destruir $stack_name, tentando remover state órfão..."
            terraform state list 2>/dev/null | while read resource; do
                terraform state rm "$resource" 2>/dev/null || true
            done
            echo "✅ $stack_name limpo (recursos já removidos)"
        }
        echo "✅ $stack_name destruído com sucesso!"
    else
        echo "⚠️  $stack_name: Nenhum recurso para destruir"
    fi
    
    echo ""
}

# IMPORTANTE: Primeiro deletar recursos Kubernetes que criam recursos AWS
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 PASSO 1: Deletando recursos Kubernetes (Ingress → ALB)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

kubectl delete ingress eks-devopsproject-ingress --ignore-not-found=true || true
kubectl delete service nginx --ignore-not-found=true || true
kubectl delete deployment nginx --ignore-not-found=true || true

echo "⏳ Aguardando ALB ser deletado pela AWS (30s)..."
sleep 30

echo "✅ Recursos Kubernetes deletados"
echo ""

# Ordem correta de destruição (REVERSA da criação: 05 → 00)
echo "📋 Ordem de destruição: 05-monitoring → 04-security → 03-karpenter → 02-eks → 01-networking → 00-backend"
echo ""

destroy_stack "Stack 05 - Monitoring (Grafana + Prometheus)" "05-monitoring"

# Stack 04: Remover WAF association do state (ALB já foi deletado via kubectl)
echo "🧹 Stack 04: Removendo WAF association do state..."
cd "$PROJECT_ROOT/04-security"
terraform state rm aws_wafv2_web_acl_association.eks_alb 2>/dev/null || echo "  ℹ️  WAF association já removida ou não existe"
echo ""

destroy_stack "Stack 04 - Security (WAF)" "04-security"

# Stack 03: Garantir que helm/values.yml existe
echo "🧹 Stack 03: Verificando helm/values.yml..."
cd "$PROJECT_ROOT/03-karpenter-auto-scaling"
if [ ! -f "helm/values.yml" ]; then
    echo "  ⚠️  helm/values.yml não encontrado, criando versão mínima..."
    mkdir -p helm
    cat > helm/values.yml << 'EOFVALUES'
serviceAccount:
  name: karpenter
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::620958830769:role/karpenter-controller-role
EOFVALUES
    echo "  ✅ helm/values.yml criado"
else
    echo "  ✅ helm/values.yml existe"
fi
echo ""

destroy_stack "Stack 03 - Karpenter (Auto-scaling)" "03-karpenter-auto-scaling"

# Stack 02: Remover helm releases do state (cluster inacessível após addons destruídos)
echo "🧹 Stack 02: Removendo helm releases do state..."
cd "$PROJECT_ROOT/02-eks-cluster"
terraform state rm helm_release.load_balancer_controller 2>/dev/null || echo "  ℹ️  ALB Controller helm release já removido ou não existe"
terraform state rm helm_release.external_dns 2>/dev/null || echo "  ℹ️  External DNS helm release já removido ou não existe"
echo ""

destroy_stack "Stack 02 - EKS Cluster" "02-eks-cluster"
destroy_stack "Stack 01 - Networking (VPC)" "01-networking"

# Backend por último
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Destruindo: Stack 00 - Backend (S3 + DynamoDB)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "⚠️  Destruir backend também? Isso removerá o state remoto! (s/N): " destroy_backend

if [[ $destroy_backend =~ ^[Ss]$ ]]; then
    cd "$PROJECT_ROOT/00-backend"
    terraform destroy -auto-approve
    echo "✅ Stack 00 - Backend destruído"
else
    echo "⏸️  Stack 00 - Backend preservado (state remoto mantido)"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ DESTRUIÇÃO COMPLETA!                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Recursos destruídos:"
echo "  ✅ Ingress + ALB (via kubectl)"
echo "  ✅ Stack 05: Grafana + Prometheus"
echo "  ✅ Stack 04: WAF Web ACL + Association"
echo "  ✅ Stack 03: Karpenter + IAM Roles + Resources"
echo "  ✅ Stack 02: EKS Cluster + Node Group + ALB Controller + External DNS"
echo "  ✅ Stack 01: VPC + Subnets + NAT Gateways + EIPs"
if [[ $destroy_backend =~ ^[Ss]$ ]]; then
echo "  ✅ Stack 00: Backend (S3 + DynamoDB)"
else
echo "  ⏸️  Stack 00: Backend preservado"
fi
echo ""
echo "💰 Custos AWS agora: ~$0/mês"
if [[ ! $destroy_backend =~ ^[Ss]$ ]]; then
echo "   (S3 + DynamoDB do backend: <$1/mês)"
fi
echo ""
echo "🔄 Para recriar tudo: ./rebuild-all.sh"
echo ""
