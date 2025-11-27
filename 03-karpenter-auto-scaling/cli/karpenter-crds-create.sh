#!/bin/bash

# Script para aplicar CRDs do Karpenter
# Versão: 1.0

set -e

echo "📦 Aplicando Karpenter CRDs..."

# Aplicar CRDs do Karpenter v1.5.0
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.sh_nodepools.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.sh_nodeclaims.yaml

echo "✅ Karpenter CRDs aplicados com sucesso!"
