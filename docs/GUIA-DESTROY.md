# 🗑️ Guia de Destroy - Destruição Segura da Infraestrutura

## ✅ Pré-requisitos Completos

### 1. Backup Realizado ✅
- **Data**: 16/01/2026 13:21:26
- **Localização**: `/home/luiz7/Projects/gitops-backup-20260116-132126/`
- **Arquivo compactado**: `gitops-backup-20260116-132126.tar.gz` (172K)
- **Conteúdo**:
  - ✅ Código fonte completo
  - ✅ Terraform states (3 stacks)
  - ✅ Recursos Kubernetes exportados
  - ✅ Configurações AWS (IAM, ECR, EKS)
  - ✅ Documentação GitHub
  - ✅ README com instruções de restore

### 2. Script destroy-all.sh Atualizado ✅
Agora inclui limpeza de:
- ✅ 7 ECR Repositories (ecommerce/*)
- ✅ IAM user github-actions-eks (access keys + policies)
- ✅ Recursos Kubernetes (namespaces + ALB)
- ✅ EKS Cluster completo
- ✅ VPC + Networking
- ✅ Backend (S3 + DynamoDB) - opcional

## 🚀 Como Executar o Destroy

### Passo 1: Verificar Backup
```bash
# Verificar que o backup existe
ls -lh /home/luiz7/Projects/gitops-backup-20260116-132126.tar.gz

# Ver conteúdo do backup
tar -tzf /home/luiz7/Projects/gitops-backup-20260116-132126.tar.gz | head -20

# Ler instruções de restore
cat /home/luiz7/Projects/gitops-backup-20260116-132126/README.md
```

### Passo 2: Executar Destroy
```bash
cd /home/luiz7/Projects/gitops

# Executar script
./scripts/destroy-all.sh
```

### Passo 3: Confirmar Destruição do Backend
Quando perguntado:
```
⚠️  Destruir backend também? Isso removerá o state remoto! (s/N):
```

**Opções:**
- **s** = Sim, destruir tudo (incluindo S3 + DynamoDB)
  - ✅ Custo: $0/mês
  - ⚠️ State remoto será perdido
  
- **N** = Não, manter backend
  - 💰 Custo: ~$1/mês (S3 + DynamoDB)
  - ✅ State remoto preservado para restore

**Recomendação**: Digite **N** para manter o backend e facilitar restore futuro.

## 📋 O Que Será Destruído

### PASSO 0: Recursos CI/CD
```
🗑️  ECR Repositories (7):
  - ecommerce/ecommerce-ui
  - ecommerce/product-catalog
  - ecommerce/order-management
  - ecommerce/product-inventory
  - ecommerce/profile-management
  - ecommerce/shipping-and-handling
  - ecommerce/contact-support-team

🗑️  IAM User:
  - github-actions-eks
    → Access keys deletadas
    → Managed policies detached (ECR + EKS)
    → Inline policy deletada (EKS-CICD-Access)
```

### PASSO 1: Recursos Kubernetes
```
🗑️  Namespace ecommerce:
  - 11 pods (v1 + v2 + microservices)
  - Services
  - Ingress → ALB (Load Balancer)
  - ConfigMaps (incluindo aws-auth)

🗑️  Namespace sample-app (se existir):
  - Sample deployment
```

### PASSO 2: Stack 02 - EKS Cluster
```
🗑️  EKS Cluster:
  - eks-devopsproject-cluster
  - Node Group (2x t3.medium EC2)
  - ALB Controller (Helm release)
  - External DNS (Helm release)
  - Metrics Server
  - EBS CSI Driver
  - OIDC Provider
  
🗑️  IAM Roles (órfãos):
  - eks-devopsproject-cluster-role
  - eks-devopsproject-node-group-role
  - aws-load-balancer-controller
  - external-dns-irsa-role
  - AmazonEKS_EFS_CSI_DriverRole
```

### PASSO 3: Stack 01 - Networking
```
🗑️  VPC:
  - eks-devopsproject-vpc (10.0.0.0/16)
  - 6 Subnets (2 public + 4 private)
  - Internet Gateway
  - 2 NAT Gateways
  - 2 Elastic IPs
  - Route Tables
  - Security Groups
```

### PASSO 4: Stack 00 - Backend (Opcional)
```
🗑️  Backend (se confirmado):
  - S3 Bucket: eks-devopsproject-state-files-794038226274
  - DynamoDB Table: eks-devopsproject-state-lock
```

## ⏱️ Tempo Estimado

| Passo | Tempo | Descrição |
|-------|-------|-----------|
| 0 - CI/CD | 1-2 min | Deletar ECR + IAM user |
| 1 - K8s | 1-2 min | Deletar namespaces + aguardar ALB |
| 2 - EKS | 5-8 min | Destruir cluster + node group |
| 3 - VPC | 2-3 min | Destruir networking |
| 4 - Backend | 1 min | Destruir S3 + DynamoDB (opcional) |
| **Total** | **10-15 min** | Tempo total estimado |

## 💰 Custos Após Destroy

### Com Backend Preservado (Recomendado)
```
✅ EKS Cluster: $0
✅ EC2 Instances: $0
✅ NAT Gateways: $0
✅ Load Balancers: $0
✅ ECR: $0
💰 S3 + DynamoDB: ~$0.50/mês
───────────────────────────
Total: ~$0.50/mês
```

### Com Backend Destruído
```
✅ Todos recursos: $0
───────────────────────────
Total: $0/mês
```

## ⚠️ Avisos Importantes

### 1. GitHub Actions
- ❌ Workflows CI/CD vão **FALHAR** após destroy
- ❌ IAM user github-actions-eks será **DELETADO**
- ⚠️ Secrets no GitHub ficarão **INVÁLIDOS**

### 2. Domínio DNS
- ⚠️ Route53 hosted zone será **MANTIDA** (não gerenciada pelo Terraform)
- ⚠️ Registros DNS precisam ser limpos **MANUALMENTE** se necessário
- 💰 Custo: $0.50/mês

### 3. Images Docker
- ⚠️ Imagens nos ECR repos serão **DELETADAS**
- 💡 Para restore: fazer novo push das imagens

### 4. Terraform State
- ⚠️ Se destruir backend: state remoto será **PERDIDO**
- ✅ Backup tem cópia do state em `terraform-states/`

## 🔄 Como Restaurar Depois

### Opção 1: Restore Rápido (Backend Preservado)
```bash
cd /home/luiz7/Projects/gitops

# Backend já existe, apenas recriar infraestrutura
./scripts/rebuild-all.sh
```

### Opção 2: Restore Completo (Backend Destruído)
```bash
# 1. Restaurar terraform states do backup
cp /home/luiz7/Projects/gitops-backup-20260116-132126/terraform-states/*.tfstate \
   /home/luiz7/Projects/gitops/

# 2. Recriar tudo
./scripts/rebuild-all.sh
```

### Recursos Adicionais a Recriar:
```bash
# 1. ECR Repositories
./scripts/setup-ecr.sh

# 2. IAM User github-actions-eks
# Seguir instruções em: backup/github-setup.md

# 3. Push images para ECR
# (instruções no README do projeto)

# 4. Reconfigurar GitHub Secrets
# https://github.com/jlui70/gitops-eks/settings/environments
```

## 📊 Checklist de Verificação Pós-Destroy

Execute após o destroy para confirmar limpeza:

```bash
# 1. Verificar EKS Cluster
aws eks list-clusters --region us-east-1
# Esperado: []

# 2. Verificar EC2 Instances
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:kubernetes.io/cluster/eks-devopsproject-cluster,Values=owned" \
  --query 'Reservations[].Instances[].InstanceId'
# Esperado: []

# 3. Verificar VPC
aws ec2 describe-vpcs --region us-east-1 \
  --filters "Name=tag:Name,Values=eks-devopsproject-vpc"
# Esperado: []

# 4. Verificar Load Balancers
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-ecommerc`)].LoadBalancerName'
# Esperado: []

# 5. Verificar ECR Repositories
aws ecr describe-repositories --region us-east-1 | grep ecommerce
# Esperado: (vazio)

# 6. Verificar IAM User
aws iam get-user --user-name github-actions-eks
# Esperado: NoSuchEntity error
```

## 🆘 Troubleshooting

### Erro: "EntityAlreadyExists" em IAM roles
```bash
# Roles órfãs não deletadas, deletar manualmente:
aws iam delete-role --role-name <role-name>
```

### Erro: ALB não deleta
```bash
# ALB criado pelo Ingress pode não ser deletado, forçar:
aws elbv2 delete-load-balancer --load-balancer-arn <arn>
```

### Erro: VPC tem dependências
```bash
# ENIs ou Security Groups órfãos, listar:
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<vpc-id>"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>"
```

### Erro: S3 bucket não esvazia
```bash
# Esvaziar manualmente:
BUCKET="eks-devopsproject-state-files-794038226274"
aws s3 rm s3://$BUCKET --recursive
aws s3api delete-bucket --bucket $BUCKET
```

## 📞 Suporte

Se encontrar problemas durante o destroy:
1. Verifique logs detalhados do script
2. Consulte backup: `/home/luiz7/Projects/gitops-backup-20260116-132126/README.md`
3. Verifique documentação: `docs/`

## 📝 Notas Finais

- ✅ Backup realizado e verificado
- ✅ Script destroy-all.sh atualizado com limpeza CI/CD
- ✅ Processo de restore documentado
- ✅ Checklist de verificação incluído
- ⚡ Tempo total: 10-15 minutos
- 💰 Custo após destroy: $0-0.50/mês

**Você está pronto para executar o destroy com segurança!** 🚀

---

**Data**: Janeiro 16, 2026  
**Versão do Script**: v4.1 (com limpeza ECR + IAM)
