#!/bin/bash

# Script de Diagnóstico - E-commerce 503 Error
# Versão: 1.0

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🔍 DIAGNÓSTICO - ERRO 503                                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar namespace
if ! kubectl get namespace ecommerce &>/dev/null; then
    echo "❌ Namespace 'ecommerce' não existe"
    exit 1
fi

echo "✅ Namespace 'ecommerce' existe"
echo ""

# ══════════════════════════════════════════════════════════════════════
# 1. VERIFICAR PODS
# ══════════════════════════════════════════════════════════════════════

echo "═══ 1. STATUS DOS PODS ═══"
echo ""

PODS=$(kubectl get pods -n ecommerce --no-headers 2>/dev/null)

if [ -z "$PODS" ]; then
    echo "❌ Nenhum pod encontrado no namespace ecommerce"
    exit 1
fi

echo "$PODS"
echo ""

# Contar pods não-ready
NOT_READY=$(echo "$PODS" | grep -v "1/1.*Running" | wc -l)

if [ "$NOT_READY" -gt 0 ]; then
    echo "⚠️  $NOT_READY pod(s) NÃO estão prontos"
    echo ""
    echo "Detalhes dos pods com problema:"
    echo ""
    
    kubectl get pods -n ecommerce --no-headers | grep -v "1/1.*Running" | while read line; do
        POD_NAME=$(echo "$line" | awk '{print $1}')
        echo "→ Pod: $POD_NAME"
        echo "  Status:"
        kubectl get pod $POD_NAME -n ecommerce
        echo ""
        echo "  Eventos recentes:"
        kubectl describe pod $POD_NAME -n ecommerce | tail -20
        echo ""
        echo "  Logs:"
        kubectl logs $POD_NAME -n ecommerce --tail=20 2>/dev/null || echo "  Sem logs disponíveis"
        echo ""
        echo "────────────────────────────────────────────────────────────────"
        echo ""
    done
else
    echo "✅ Todos os pods estão Running e Ready (1/1)"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# 2. VERIFICAR SERVICES
# ══════════════════════════════════════════════════════════════════════

echo "═══ 2. STATUS DOS SERVICES ═══"
echo ""

kubectl get svc -n ecommerce

echo ""

# Verificar endpoints
echo "→ Verificando endpoints (pods conectados aos services):"
echo ""

for svc in $(kubectl get svc -n ecommerce --no-headers | awk '{print $1}'); do
    ENDPOINTS=$(kubectl get endpoints $svc -n ecommerce -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    
    if [ -z "$ENDPOINTS" ]; then
        echo "   ❌ Service '$svc' SEM endpoints (nenhum pod conectado)"
    else
        EP_COUNT=$(echo "$ENDPOINTS" | wc -w)
        echo "   ✅ Service '$svc' tem $EP_COUNT endpoint(s)"
    fi
done

echo ""

# ══════════════════════════════════════════════════════════════════════
# 3. VERIFICAR INGRESS
# ══════════════════════════════════════════════════════════════════════

echo "═══ 3. STATUS DO INGRESS ═══"
echo ""

kubectl get ingress -n ecommerce

echo ""

INGRESS_ADDRESS=$(kubectl get ingress ecommerce-ingress -n ecommerce \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$INGRESS_ADDRESS" ]; then
    echo "❌ Ingress NÃO tem ALB provisionado"
    echo ""
    echo "Verifique os eventos do ingress:"
    kubectl describe ingress ecommerce-ingress -n ecommerce
else
    echo "✅ ALB provisionado: $INGRESS_ADDRESS"
fi

echo ""
echo "→ Detalhes do Ingress:"
kubectl describe ingress ecommerce-ingress -n ecommerce

echo ""

# ══════════════════════════════════════════════════════════════════════
# 4. VERIFICAR AWS LOAD BALANCER CONTROLLER
# ══════════════════════════════════════════════════════════════════════

echo "═══ 4. AWS LOAD BALANCER CONTROLLER ═══"
echo ""

ALB_CONTROLLER=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null)

if [ -z "$ALB_CONTROLLER" ]; then
    echo "❌ AWS Load Balancer Controller NÃO encontrado"
    echo ""
    echo "O controller é necessário para criar o ALB"
    echo "Verifique se foi instalado corretamente na stack 02"
else
    echo "✅ Controller encontrado:"
    echo "$ALB_CONTROLLER"
    echo ""
    
    # Verificar se está rodando
    CONTROLLER_READY=$(echo "$ALB_CONTROLLER" | grep "2/2.*Running" | wc -l)
    
    if [ "$CONTROLLER_READY" -eq 0 ]; then
        echo "⚠️  Controller NÃO está pronto (2/2)"
        echo ""
        echo "Logs do controller:"
        kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
    else
        echo "✅ Controller está pronto e rodando"
    fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# 5. TESTAR CONECTIVIDADE
# ══════════════════════════════════════════════════════════════════════

echo "═══ 5. TESTE DE CONECTIVIDADE ═══"
echo ""

# Teste interno (pod to pod)
echo "→ Testando conectividade interna (pod → service):"
echo ""

UI_POD=$(kubectl get pods -n ecommerce -l app=ecommerce-ui --no-headers -o custom-columns=":metadata.name" | head -1)

if [ -n "$UI_POD" ]; then
    echo "   Testando de $UI_POD → product-catalog..."
    kubectl exec -n ecommerce $UI_POD -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://product-catalog:3001/ 2>/dev/null || echo "   ❌ Falha na conexão"
    
    echo "   Testando de $UI_POD → order-management..."
    kubectl exec -n ecommerce $UI_POD -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://order-management:9090/ 2>/dev/null || echo "   ❌ Falha na conexão"
else
    echo "   ⚠️  Nenhum pod ecommerce-ui encontrado para teste"
fi

echo ""

# Teste externo (ALB)
if [ -n "$INGRESS_ADDRESS" ]; then
    echo "→ Testando conectividade externa (ALB):"
    echo "   URL: http://$INGRESS_ADDRESS"
    echo ""
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_ADDRESS" 2>/dev/null || echo "000")
    
    if [ "$HTTP_STATUS" == "200" ]; then
        echo "   ✅ ALB respondendo: HTTP $HTTP_STATUS"
    elif [ "$HTTP_STATUS" == "503" ]; then
        echo "   ❌ ALB retornando: HTTP 503 (Service Unavailable)"
        echo ""
        echo "   Causa mais comum: Target Group sem targets saudáveis"
        echo ""
        echo "   Possíveis problemas:"
        echo "   1. Pods não estão respondendo nas health checks"
        echo "   2. Security Groups bloqueando tráfego"
        echo "   3. Service selector não encontra pods"
        echo "   4. Porta incorreta no service/ingress"
    else
        echo "   ⚠️  ALB retornando: HTTP $HTTP_STATUS"
    fi
    
    echo ""
    
    # Informações adicionais do ALB
    echo "   Checando Target Group no AWS..."
    echo "   (Isso requer AWS CLI configurado)"
    echo ""
    
    # Extrair nome do ALB
    ALB_NAME=$(echo "$INGRESS_ADDRESS" | cut -d'-' -f1-3)
    
    # Tentar obter informações do Target Group
    TG_ARN=$(aws elbv2 describe-target-groups \
        --region us-east-1 \
        --query "TargetGroups[?contains(LoadBalancerArns[0], '$ALB_NAME')].TargetGroupArn" \
        --output text 2>/dev/null | head -1)
    
    if [ -n "$TG_ARN" ]; then
        echo "   Target Group encontrado: $(basename $TG_ARN)"
        echo ""
        echo "   Targets registrados:"
        aws elbv2 describe-target-health \
            --target-group-arn "$TG_ARN" \
            --region us-east-1 \
            --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
            --output table 2>/dev/null || echo "   Erro ao obter targets"
    else
        echo "   ⚠️  Não foi possível obter informações do Target Group"
    fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════
# 6. RESUMO E RECOMENDAÇÕES
# ══════════════════════════════════════════════════════════════════════

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     📋 RESUMO E RECOMENDAÇÕES                                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$NOT_READY" -gt 0 ]; then
    echo "❌ PROBLEMA: Pods não estão prontos"
    echo "   → Verifique os logs dos pods com erro acima"
    echo "   → Comando: kubectl logs <pod-name> -n ecommerce"
    echo ""
fi

if [ -z "$INGRESS_ADDRESS" ]; then
    echo "❌ PROBLEMA: ALB não foi provisionado"
    echo "   → Verifique se ALB Controller está rodando"
    echo "   → Verifique eventos do ingress acima"
    echo ""
fi

if [ "$HTTP_STATUS" == "503" ]; then
    echo "❌ PROBLEMA: ALB retorna 503"
    echo ""
    echo "   Checklist:"
    echo "   1. ✓ Todos os pods estão Ready (1/1)?"
    echo "   2. ✓ Services têm endpoints conectados?"
    echo "   3. ✓ Porta do service bate com porta do container?"
    echo "   4. ✓ Selector do service encontra os pods?"
    echo "   5. ✓ Ingress aponta para o service correto?"
    echo ""
    echo "   Comandos de debug:"
    echo "   kubectl get pods -n ecommerce -o wide"
    echo "   kubectl get endpoints -n ecommerce"
    echo "   kubectl logs -n ecommerce deployment/ecommerce-ui"
    echo "   kubectl exec -n ecommerce <pod> -- curl -v http://localhost:4000"
    echo ""
fi

echo "════════════════════════════════════════════════════════════════════"
echo ""
