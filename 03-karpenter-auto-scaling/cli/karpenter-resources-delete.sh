#!/bin/bash

# Script para deletar recursos do Karpenter
# Versão: 1.0

set -e

echo "🗑️ Deletando Karpenter Resources..."

# Deletar NodePool
kubectl delete -f resources/karpenter-node-pool.yml --ignore-not-found=true

# Deletar EC2NodeClass  
kubectl delete -f resources/karpenter-node-class.yml --ignore-not-found=true

echo "✅ Karpenter Resources deletados com sucesso!"
