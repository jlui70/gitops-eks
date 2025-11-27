#!/bin/bash

# Script para aplicar recursos do Karpenter (NodePool e EC2NodeClass)
# Versão: 1.0

set -e

echo "📦 Aplicando Karpenter Resources (NodePool + EC2NodeClass)..."

# Aplicar NodePool
kubectl apply -f resources/karpenter-node-pool.yml

# Aplicar EC2NodeClass
kubectl apply -f resources/karpenter-node-class.yml

echo "✅ Karpenter Resources aplicados com sucesso!"
