#!/bin/bash

# Script para deletar CRDs do Karpenter
# Versão: 1.0

set -e

echo "🗑️ Deletando Karpenter CRDs..."

# Deletar CRDs do Karpenter v1.5.0
kubectl delete -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.sh_nodepools.yaml --ignore-not-found=true
kubectl delete -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml --ignore-not-found=true
kubectl delete -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.sh_nodeclaims.yaml --ignore-not-found=true

echo "✅ Karpenter CRDs deletados com sucesso!"
