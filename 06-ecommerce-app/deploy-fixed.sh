#!/bin/bash

# Script de Deploy da Aplicação E-commerce - Versão Corrigida
# EKS DevOps Project - Microservices Demo

set -e  # Exit on error

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🚀 Deploy E-commerce - EKS DevOps Project                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ══════════════════════════════════════════════════════════════════════
# VERIFICAÇÕES INICIAIS
# ══════════════════════════════════════════════════════════════════════

echo "🔍 Verificando pré-requisitos..."

# Verificar kubectl
if ! command -v kubectl &>/dev/null; then
    echo "❌ kubectl não encontrado. Instale o kubectl primeiro."
    exit 1
fi

# Verificar conexão com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster EKS"
    echo ""
    echo "Execute primeiro:"
    echo "  aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1"
    exit 1
fi

echo "✅ kubectl configurado"
echo "✅ Cluster EKS acessível"
echo ""

# ══════════════════════════════════════════════════════════════════════
# LIMPEZA (se necessário)
# ══════════════════════════════════════════════════════════════════════

if kubectl get namespace ecommerce &>/dev/null; then
    echo "⚠️  Namespace 'ecommerce' já existe"
    echo ""
    read -p "Deseja DELETAR a aplicação existente e fazer deploy limpo? (s/N): " confirm
    
    if [[ $confirm =~ ^[Ss]$ ]]; then
        echo ""
        echo "🗑️  Deletando namespace ecommerce..."
        kubectl delete namespace ecommerce --timeout=60s || true
        
        echo "⏳ Aguardando namespace ser removido completamente..."
        while kubectl get namespace ecommerce &>/dev/null; do
            echo "   → Aguardando..."
            sleep 5
        done
        
        echo "✅ Namespace removido"
        echo ""
    else
        echo ""
        echo "⚠️  ATENÇÃO: Deploy incremental pode causar erros 'field is immutable'"
        echo "   Recomendação: Delete o namespace primeiro com:"
        echo "   kubectl delete namespace ecommerce"
        echo ""
        read -p "Continuar mesmo assim? (s/N): " force_continue
        
        if [[ ! $force_continue =~ ^[Ss]$ ]]; then
            echo "❌ Deploy cancelado"
            exit 0
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════
# DEPLOY DOS MANIFESTS
# ══════════════════════════════════════════════════════════════════════

echo "📦 Aplicando manifests Kubernetes..."
echo ""

# Criar namespace primeiro
echo "→ Criando namespace..."
kubectl apply -f manifests/00-namespace.yaml

# Aguardar namespace estar pronto
sleep 2

# Aplicar todos os manifests (ordem correta)
echo "→ Aplicando frontend..."
kubectl apply -f manifests/ecommerce-ui.yaml

echo "→ Aplicando microserviços..."
kubectl apply -f manifests/product-catalog.yaml
kubectl apply -f manifests/order-management.yaml
kubectl apply -f manifests/product-inventory.yaml
kubectl apply -f manifests/profile-management.yaml
kubectl apply -f manifests/shipping-and-handling.yaml
kubectl apply -f manifests/team-contact-support.yaml

echo "→ Aplicando ingress..."
kubectl apply -f manifests/ingress.yaml

echo ""
echo "✅ Manifests aplicados"
echo ""

# ══════════════════════════════════════════════════════════════════════
# AGUARDAR DEPLOYMENTS ESTAREM PRONTOS
# ══════════════════════════════════════════════════════════════════════

echo "⏳ Aguardando pods iniciarem..."
echo ""

# Lista de deployments (nomes CORRETOS)
DEPLOYMENTS=(
    "product-catalog"
    "order-management"
    "product-inventory"
    "profile-management"
    "shipping-and-handling"
    "contact-support-team"
    "ecommerce-ui"
)

# Aguardar cada deployment
for deployment in "${DEPLOYMENTS[@]}"; do
    echo "   → Aguardando $deployment..."
    
    # Timeout de 5 minutos
    if kubectl wait --for=condition=available \
        deployment/$deployment \
        -n ecommerce \
        --timeout=300s 2>/dev/null; then
        echo "      ✅ $deployment pronto"
    else
        echo "      ⚠️  $deployment demorou mais que esperado"
        echo "         Verificando status..."
        kubectl get deployment $deployment -n ecommerce
        kubectl get pods -n ecommerce -l app=$deployment
    fi
done

echo ""
echo "✅ Todos os deployments iniciados"
echo ""

# ══════════════════════════════════════════════════════════════════════
# AGUARDAR INGRESS / ALB
# ══════════════════════════════════════════════════════════════════════

echo "🌐 Aguardando Application Load Balancer ser provisionado..."
echo "   (Isso pode levar 2-3 minutos...)"
echo ""

INGRESS_ADDRESS=""
MAX_ATTEMPTS=24  # 24 * 15s = 6 minutos

for i in $(seq 1 $MAX_ATTEMPTS); do
    INGRESS_ADDRESS=$(kubectl get ingress ecommerce-ingress -n ecommerce \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [[ -n "$INGRESS_ADDRESS" ]]; then
        echo "✅ ALB provisionado: $INGRESS_ADDRESS"
        break
    fi
    
    echo "   Tentativa $i/$MAX_ATTEMPTS: Aguardando ALB..."
    sleep 15
done

if [[ -z "$INGRESS_ADDRESS" ]]; then
    echo ""
    echo "⚠️  ALB ainda não foi provisionado após 6 minutos"
    echo "   Isso é incomum. Verifique:"
    echo "   1. AWS Load Balancer Controller está rodando?"
    echo "      kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
    echo "   2. Ingress tem anotações corretas?"
    echo "      kubectl describe ingress ecommerce-ingress -n ecommerce"
    echo ""
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# STATUS FINAL
# ══════════════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     📊 STATUS DA APLICAÇÃO                                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "🎯 Deployments:"
kubectl get deployments -n ecommerce -o wide

echo ""
echo "🎯 Pods:"
kubectl get pods -n ecommerce -o wide

echo ""
echo "🔗 Services:"
kubectl get svc -n ecommerce

echo ""
echo "🌐 Ingress:"
kubectl get ingress -n ecommerce

echo ""

# ══════════════════════════════════════════════════════════════════════
# INFORMAÇÕES DE ACESSO
# ══════════════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🎉 DEPLOY CONCLUÍDO!                                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "📍 URLs de Acesso:"
echo ""

if [[ -n "$INGRESS_ADDRESS" ]]; then
    echo "   🔧 ALB Direto:"
    echo "      http://$INGRESS_ADDRESS"
    echo ""
fi

echo "   🎯 DNS Personalizado (se configurado):"
echo "      http://eks.devopsproject.com.br"
echo ""

# ══════════════════════════════════════════════════════════════════════
# TESTE DE CONECTIVIDADE
# ══════════════════════════════════════════════════════════════════════

if [[ -n "$INGRESS_ADDRESS" ]]; then
    echo "🧪 Testando conectividade com ALB..."
    echo "   (Aguardando ALB estar totalmente pronto - 60s)"
    sleep 60
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_ADDRESS" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "   ✅ Aplicação respondendo corretamente (HTTP $HTTP_STATUS)"
    elif [[ "$HTTP_STATUS" == "503" ]]; then
        echo "   ⚠️  ALB retornou 503 (Service Unavailable)"
        echo ""
        echo "   Possíveis causas:"
        echo "   1. Target groups sem targets saudáveis"
        echo "   2. Pods não estão prontos ainda"
        echo "   3. Ingress rules com problemas"
        echo ""
        echo "   Aguarde mais 2-3 minutos e teste novamente"
        echo ""
        echo "   Debug:"
        echo "   kubectl get pods -n ecommerce"
        echo "   kubectl logs -n ecommerce deployment/ecommerce-ui"
        echo "   kubectl describe ingress ecommerce-ingress -n ecommerce"
    else
        echo "   ⚠️  Status inesperado: HTTP $HTTP_STATUS"
        echo "   Aguarde alguns minutos para ALB terminar de provisionar"
    fi
    echo ""
fi

# ══════════════════════════════════════════════════════════════════════
# COMANDOS ÚTEIS
# ══════════════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🔧 COMANDOS ÚTEIS                                           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "📊 Monitoramento:"
echo "   kubectl get all -n ecommerce"
echo "   kubectl get pods -n ecommerce -w"
echo ""

echo "📝 Logs:"
echo "   kubectl logs -f deployment/ecommerce-ui -n ecommerce"
echo "   kubectl logs -f deployment/product-catalog -n ecommerce"
echo ""

echo "🔍 Debug:"
echo "   kubectl describe pod <pod-name> -n ecommerce"
echo "   kubectl describe ingress ecommerce-ingress -n ecommerce"
echo ""

echo "🌐 Port-forward (teste local):"
echo "   kubectl port-forward svc/ecommerce-ui 8080:4000 -n ecommerce"
echo "   Acesse: http://localhost:8080"
echo ""

echo "🗑️  Remover aplicação:"
echo "   kubectl delete namespace ecommerce"
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo "✨ Deploy finalizado! Acesse a aplicação via ALB"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
