#!/bin/bash

# Script de Backup Completo antes do Destroy
# Data: $(date)
# Backup de todos os recursos e configurações

set -e

BACKUP_DIR="/home/luiz7/Projects/gitops-backup-$(date +%Y%m%d-%H%M%S)"
PROJECT_ROOT="/home/luiz7/Projects/gitops"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           📦 BACKUP COMPLETO ANTES DO DESTROY                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Backup será salvo em: $BACKUP_DIR"
echo ""

mkdir -p "$BACKUP_DIR"

# 1. Backup do código fonte
echo "═══════════════════════════════════════════════════════════════════"
echo "📂 1. Copiando código fonte e manifestos"
echo "═══════════════════════════════════════════════════════════════════"
rsync -av --exclude='.git' \
  --exclude='node_modules' \
  --exclude='.terraform' \
  --exclude='*.tfstate*' \
  "$PROJECT_ROOT/" "$BACKUP_DIR/source/" 2>/dev/null
echo "✅ Código fonte copiado"
echo ""

# 2. Backup dos Terraform states
echo "═══════════════════════════════════════════════════════════════════"
echo "💾 2. Salvando Terraform states"
echo "═══════════════════════════════════════════════════════════════════"
mkdir -p "$BACKUP_DIR/terraform-states"

for stack in 00-backend 01-networking 02-eks-cluster; do
  if [ -f "$PROJECT_ROOT/$stack/terraform.tfstate" ]; then
    cp "$PROJECT_ROOT/$stack/terraform.tfstate" "$BACKUP_DIR/terraform-states/$stack.tfstate"
    echo "  ✅ $stack state salvo"
  fi
done
echo ""

# 3. Backup dos recursos Kubernetes
echo "═══════════════════════════════════════════════════════════════════"
echo "☸️  3. Exportando recursos Kubernetes"
echo "═══════════════════════════════════════════════════════════════════"
mkdir -p "$BACKUP_DIR/kubernetes"

if kubectl cluster-info &>/dev/null; then
  # Namespaces
  kubectl get namespaces -o yaml > "$BACKUP_DIR/kubernetes/namespaces.yaml" 2>/dev/null || true
  
  # Namespace ecommerce completo
  kubectl get all,configmap,ingress,secret -n ecommerce -o yaml > "$BACKUP_DIR/kubernetes/ecommerce-namespace.yaml" 2>/dev/null || true
  
  # aws-auth ConfigMap
  kubectl get configmap aws-auth -n kube-system -o yaml > "$BACKUP_DIR/kubernetes/aws-auth-configmap.yaml" 2>/dev/null || true
  
  # Nodes
  kubectl get nodes -o yaml > "$BACKUP_DIR/kubernetes/nodes.yaml" 2>/dev/null || true
  
  echo "  ✅ Recursos Kubernetes exportados"
else
  echo "  ⚠️  Cluster inacessível, pulando backup K8s"
fi
echo ""

# 4. Backup configurações AWS
echo "═══════════════════════════════════════════════════════════════════"
echo "☁️  4. Exportando configurações AWS"
echo "═══════════════════════════════════════════════════════════════════"
mkdir -p "$BACKUP_DIR/aws-config"

# IAM User github-actions-eks
aws iam get-user --user-name github-actions-eks > "$BACKUP_DIR/aws-config/iam-user-github-actions-eks.json" 2>/dev/null || true
aws iam list-attached-user-policies --user-name github-actions-eks > "$BACKUP_DIR/aws-config/iam-user-attached-policies.json" 2>/dev/null || true
aws iam list-user-policies --user-name github-actions-eks > "$BACKUP_DIR/aws-config/iam-user-inline-policies.json" 2>/dev/null || true
aws iam get-user-policy --user-name github-actions-eks --policy-name EKS-CICD-Access > "$BACKUP_DIR/aws-config/iam-inline-policy-eks-cicd-access.json" 2>/dev/null || true

# ECR Repositories
aws ecr describe-repositories --region us-east-1 > "$BACKUP_DIR/aws-config/ecr-repositories.json" 2>/dev/null || true

# EKS Cluster info
aws eks describe-cluster --name eks-devopsproject-cluster --region us-east-1 > "$BACKUP_DIR/aws-config/eks-cluster-info.json" 2>/dev/null || true

# VPC info
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-devopsproject-vpc" --region us-east-1 > "$BACKUP_DIR/aws-config/vpc-info.json" 2>/dev/null || true

echo "  ✅ Configurações AWS exportadas"
echo ""

# 5. Backup credenciais GitHub (Environment Secrets - apenas referência)
echo "═══════════════════════════════════════════════════════════════════"
echo "🔐 5. Documentando configurações GitHub"
echo "═══════════════════════════════════════════════════════════════════"
cat > "$BACKUP_DIR/github-setup.md" << 'EOF'
# GitHub Configuration Backup

## Repository
- URL: https://github.com/jlui70/gitops-eks
- Branch: main

## Environment: production

### Secrets Configurados:
1. AWS_ACCESS_KEY_ID (do IAM user github-actions-eks)
2. AWS_SECRET_ACCESS_KEY (do IAM user github-actions-eks)
3. AWS_ACCOUNT_ID: 794038226274

### IAM User: github-actions-eks
- Access Key ID: AKIA3RYC5ZVRFWZEQUP6
- ⚠️ Secret Access Key: NÃO SALVO (se perdida, gerar nova)

### Policies Attached:
- AmazonEC2ContainerRegistryFullAccess (managed)
- AmazonEKSClusterPolicy (managed)
- EKS-CICD-Access (inline)

### Kubernetes RBAC:
- User ARN: arn:aws:iam::794038226274:user/github-actions-eks
- Group: system:masters (cluster admin)
EOF
echo "  ✅ Configurações GitHub documentadas"
echo ""

# 6. Criar README do backup
echo "═══════════════════════════════════════════════════════════════════"
echo "📝 6. Gerando README do backup"
echo "═══════════════════════════════════════════════════════════════════"
cat > "$BACKUP_DIR/README.md" << EOF
# Backup GitOps EKS Project

**Data do Backup**: $(date)
**Projeto**: GitOps EKS DevOps Project
**Account ID**: 794038226274
**Cluster**: eks-devopsproject-cluster

## 📂 Estrutura do Backup

\`\`\`
$BACKUP_DIR/
├── source/                    # Código fonte completo
│   ├── .github/              # GitHub Actions workflows
│   ├── 00-backend/           # Terraform backend
│   ├── 01-networking/        # Terraform networking
│   ├── 02-eks-cluster/       # Terraform EKS
│   ├── 06-ecommerce-app/     # Manifestos Kubernetes
│   ├── docs/                 # Documentação
│   └── scripts/              # Scripts utilitários
├── terraform-states/          # Estados Terraform
│   ├── 00-backend.tfstate
│   ├── 01-networking.tfstate
│   └── 02-eks-cluster.tfstate
├── kubernetes/                # Recursos K8s exportados
│   ├── namespaces.yaml
│   ├── ecommerce-namespace.yaml
│   ├── aws-auth-configmap.yaml
│   └── nodes.yaml
├── aws-config/                # Configurações AWS
│   ├── iam-user-github-actions-eks.json
│   ├── ecr-repositories.json
│   └── eks-cluster-info.json
├── github-setup.md            # Config GitHub/Secrets
└── README.md                  # Este arquivo

\`\`\`

## 🔄 Como Restaurar

### 1. Restaurar Terraform States
\`\`\`bash
cd /home/luiz7/Projects/gitops

# Copiar states de volta
cp $BACKUP_DIR/terraform-states/*.tfstate 00-backend/
cp $BACKUP_DIR/terraform-states/*.tfstate 01-networking/
cp $BACKUP_DIR/terraform-states/*.tfstate 02-eks-cluster/
\`\`\`

### 2. Recriar Infraestrutura
\`\`\`bash
./scripts/rebuild-all.sh
\`\`\`

### 3. Recriar IAM User github-actions-eks
\`\`\`bash
# Criar user
aws iam create-user --user-name github-actions-eks

# Attach policies
aws iam attach-user-policy --user-name github-actions-eks \\
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

aws iam attach-user-policy --user-name github-actions-eks \\
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# Create inline policy
aws iam put-user-policy --user-name github-actions-eks \\
  --policy-name EKS-CICD-Access \\
  --policy-document file://aws-config/iam-inline-policy-eks-cicd-access.json

# Gerar access key
aws iam create-access-key --user-name github-actions-eks
\`\`\`

### 4. Recriar ECR Repositories
\`\`\`bash
./scripts/setup-ecr.sh
\`\`\`

### 5. Restaurar aws-auth ConfigMap
\`\`\`bash
kubectl apply -f $BACKUP_DIR/kubernetes/aws-auth-configmap.yaml
\`\`\`

### 6. Reconfigurar GitHub Secrets
- Acesse: https://github.com/jlui70/gitops-eks/settings/environments
- Environment: production
- Adicione os 3 secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ACCOUNT_ID)

## 📋 Recursos Salvos

### Terraform
- [x] Backend state (S3 + DynamoDB)
- [x] Networking state (VPC + Subnets)
- [x] EKS Cluster state

### Kubernetes
- [x] Namespace ecommerce completo
- [x] ConfigMap aws-auth
- [x] Deployments v1 e v2
- [x] Services
- [x] Ingress (ALB)

### AWS
- [x] IAM user github-actions-eks + policies
- [x] 7 ECR repositories
- [x] EKS cluster configuration
- [x] VPC configuration

### GitHub
- [x] Workflows (CI, CD, Rollback)
- [x] Environment configuration (referência)

## ⚠️ Importante

- **Access Keys**: Se perdidas, gerar novas via \`aws iam create-access-key\`
- **ECR Images**: Não incluídas no backup (muito grandes), usar \`docker push\` após restore
- **GitHub Secrets**: Reconfigurar manualmente no GitHub

## 💰 Custo após Restore

- EKS Cluster: ~\$73/mês
- EC2 (2 t3.medium): ~\$60/mês
- NAT Gateway: ~\$32/mês
- ALB: ~\$16/mês
- Total: ~\$181/mês

EOF

echo "  ✅ README criado"
echo ""

# Criar tarball compactado
echo "═══════════════════════════════════════════════════════════════════"
echo "🗜️  7. Compactando backup"
echo "═══════════════════════════════════════════════════════════════════"
cd "$(dirname $BACKUP_DIR)"
tar -czf "$(basename $BACKUP_DIR).tar.gz" "$(basename $BACKUP_DIR)" 2>/dev/null
BACKUP_SIZE=$(du -sh "$BACKUP_DIR.tar.gz" | cut -f1)
echo "  ✅ Backup compactado: $BACKUP_DIR.tar.gz ($BACKUP_SIZE)"
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ BACKUP COMPLETO!                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Backup salvo em:"
echo "   • Pasta: $BACKUP_DIR/"
echo "   • Arquivo: $BACKUP_DIR.tar.gz"
echo "   • Tamanho: $BACKUP_SIZE"
echo ""
echo "📋 Conteúdo:"
echo "   ✅ Código fonte completo"
echo "   ✅ Terraform states (3 stacks)"
echo "   ✅ Recursos Kubernetes exportados"
echo "   ✅ Configurações AWS (IAM, ECR, EKS)"
echo "   ✅ Documentação GitHub"
echo "   ✅ README com instruções de restore"
echo ""
echo "🔄 Para restaurar: Consulte $BACKUP_DIR/README.md"
echo ""
