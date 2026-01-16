#!/bin/bash

# Script de Deploy da Versão 2.0 - E-commerce App
# Blue/Green Deployment Strategy

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       🚀 DEPLOYING E-COMMERCE VERSION 2.0                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar conexão com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Erro: Não foi possível conectar ao cluster EKS"
    echo "Execute: aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1"
    exit 1
fi

echo "✅ Cluster EKS conectado"
echo ""

# Verificar namespace
if ! kubectl get namespace ecommerce >/dev/null 2>&1; then
    echo "❌ Erro: Namespace 'ecommerce' não existe"
    echo "Execute primeiro o deploy v1: cd ../ansible && ansible-playbook playbooks/03-deploy-ecommerce.yml"
    exit 1
fi

echo "📋 Status atual da aplicação:"
kubectl get deployments -n ecommerce -l app=ecommerce-ui
echo ""

# Deploy v2
echo "🚀 Deploying Version 2.0 (Blue/Green Strategy)..."
echo ""

echo "  📦 Step 1/4: Aplicando ConfigMap NGINX v2..."
kubectl apply -f manifests-v2/configmap-nginx-v2.yaml

echo "  📦 Step 2/4: Deploying backend v2..."
kubectl apply -f manifests-v2/ecommerce-ui-backend.yaml

echo "  📦 Step 3/4: Deploying NGINX proxy v2..."
kubectl apply -f manifests-v2/ecommerce-ui-v2-proxy.yaml

echo "  ⏳ Step 4/4: Aguardando pods v2 ficarem prontos..."
kubectl wait --for=condition=available --timeout=300s deployment/ecommerce-ui-v2 -n ecommerce
kubectl wait --for=condition=available --timeout=300s deployment/ecommerce-ui-backend -n ecommerce

echo ""
echo "✅ Version 2.0 deployada com sucesso!"
echo ""

# Mostrar status
echo "📊 Status dos deployments:"
kubectl get deployments -n ecommerce -l app=ecommerce-ui -o wide
echo ""

echo "📊 Pods rodando:"
kubectl get pods -n ecommerce -l app=ecommerce-ui -o wide
echo ""

# Aguardar NGINX inicializar completamente
echo "⏳ Aguardando NGINX inicializar (15s)..."
sleep 15
echo ""

# Testar v2 internamente
echo "🧪 Testando endpoint v2..."
POD_V2=$(kubectl get pod -n ecommerce -l version=v2 -o jsonpath='{.items[0].metadata.name}')
echo "Pod v2: $POD_V2"
echo ""

echo "Testando /api/version:"
if kubectl exec -n ecommerce $POD_V2 -- sh -c "wget -qO- http://127.0.0.1:4000/api/version" 2>/dev/null; then
    echo ""
    echo "✅ Endpoint funcionando!"
else
    echo ""
    echo "⚠️  Endpoint ainda não respondeu, mas deployment concluído"
    echo "   Aguarde mais alguns segundos e teste manualmente"
fi
echo ""

# Instruções para switch de tráfego
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ V2 PRONTA!                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "🔄 PRÓXIMOS PASSOS:"
echo ""
echo "1. Testar v2 internamente:"
echo "   kubectl port-forward -n ecommerce svc/ecommerce-ui-v2 8080:4000"
echo "   Abra: http://localhost:8080"
echo ""
echo "2. Verificar logs v2:"
echo "   kubectl logs -n ecommerce -l version=v2 --tail=50"
echo ""
echo "3. SWITCH TRÁFEGO v1 → v2 (Blue/Green):"
echo "   ./switch-to-v2.sh"
echo ""
echo "4. ROLLBACK v2 → v1 (se necessário):"
echo "   ./rollback-to-v1.sh"
echo ""
echo "💡 Dica: v1 e v2 estão rodando em paralelo (Blue/Green)"
echo "   O Ingress ainda aponta para v1. Use switch-to-v2.sh para mudar."
echo ""
