#!/bin/bash

# Script para fazer switch do tráfego de v1 para v2
# Blue/Green Deployment - Traffic Switch

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║      🔄 SWITCHING TRAFFIC: v1 → v2                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se v2 está rodando
if ! kubectl get deployment ecommerce-ui-v2 -n ecommerce >/dev/null 2>&1; then
    echo "❌ Erro: Deployment v2 não encontrado"
    echo "Execute primeiro: ./deploy-v2.sh"
    exit 1
fi

# Verificar se v2 está healthy
READY_REPLICAS=$(kubectl get deployment ecommerce-ui-v2 -n ecommerce -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment ecommerce-ui-v2 -n ecommerce -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]; then
    echo "❌ Erro: v2 não está pronta ($READY_REPLICAS/$DESIRED_REPLICAS replicas)"
    echo "Aguarde todos os pods ficarem Ready"
    exit 1
fi

echo "✅ v2 está healthy ($READY_REPLICAS/$DESIRED_REPLICAS replicas)"
echo ""

# Perguntar confirmação
echo "⚠️  Esta ação irá redirecionar TODO o tráfego de v1 para v2"
echo ""
read -p "Deseja continuar? (S/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo ""
echo "🔄 Switching traffic..."
echo ""

# Atualizar service para apontar para v2
kubectl patch service ecommerce-ui -n ecommerce -p '{"spec":{"selector":{"version":"v2"}}}'

echo ""
echo "✅ Tráfego redirecionado para v2!"
echo ""

# Aguardar propagação
echo "⏳ Aguardando propagação (10s)..."
sleep 10

# Testar novo endpoint
echo "🧪 Testando endpoint público..."
echo ""

ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$ALB_URL" ]; then
    echo "⚠️  ALB URL não encontrado, mas switch foi concluído"
else
    echo "ALB URL: http://$ALB_URL"
    echo ""
    echo "Testando /api/version:"
    curl -s http://$ALB_URL/api/version | jq . || echo "Endpoint acessível"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              ✅ TRAFFIC SWITCHED TO V2!                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Status atual:"
kubectl get pods -n ecommerce -l app=ecommerce-ui -o wide
echo ""
echo "🌐 Acesse a aplicação:"
echo "   http://$ALB_URL"
echo "   ou"
echo "   http://eks.devopsproject.com.br"
echo ""
echo "👀 Você deve ver o banner: '🚀 VERSION 2.0 - NEW FEATURES ENABLED! 🚀'"
echo ""
echo "🔙 Para fazer rollback:"
echo "   ./rollback-to-v1.sh"
echo ""
