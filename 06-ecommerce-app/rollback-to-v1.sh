#!/bin/bash

# Script de Rollback: v2 → v1
# Reverte o tráfego para a versão estável

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║      🔙 ROLLBACK: v2 → v1                                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Perguntar motivo do rollback
echo "⚠️  ROLLBACK ALERT!"
echo ""
read -p "Motivo do rollback: " REASON
echo ""

if [ -z "$REASON" ]; then
    REASON="Não especificado"
fi

echo "📝 Motivo: $REASON"
echo ""

# Confirmar
read -p "Deseja prosseguir com o rollback? (S/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Rollback cancelado"
    exit 0
fi

echo ""
echo "🔄 Executando rollback..."
echo ""

# Reverter service para v1
kubectl patch service ecommerce-ui -n ecommerce -p '{"spec":{"selector":{"version":"v1"}}}'

echo "✅ Tráfego redirecionado para v1!"
echo ""

# Aguardar propagação
echo "⏳ Aguardando propagação (10s)..."
sleep 10

# Validar
echo "🧪 Validando rollback..."
POD_V1=$(kubectl get pod -n ecommerce -l version=v1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_V1" ]; then
    echo "✅ v1 respondendo: $POD_V1"
else
    echo "⚠️  Aviso: Não foi possível validar pod v1"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║            ✅ ROLLBACK CONCLUÍDO!                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Status atual:"
kubectl get pods -n ecommerce -l app=ecommerce-ui -o wide
echo ""
echo "🌐 Aplicação voltou para v1"
echo ""
echo "📝 Log do rollback:"
echo "   Data: $(date)"
echo "   Motivo: $REASON"
echo "   v2 ainda está rodando (pode ser removida com kubectl delete)"
echo ""
echo "🗑️  Para remover v2 completamente:"
echo "   kubectl delete deployment ecommerce-ui-v2 -n ecommerce"
echo "   kubectl delete deployment ecommerce-ui-backend -n ecommerce"
echo "   kubectl delete service ecommerce-ui-v2 -n ecommerce"
echo "   kubectl delete service ecommerce-ui-backend -n ecommerce"
echo ""
