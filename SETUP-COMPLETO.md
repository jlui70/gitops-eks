# 🚀 Setup Completo do Projeto - GitOps EKS CI/CD

Este guia orienta como configurar o projeto do zero no seu próprio ambiente AWS/GitHub.

---

## 📋 PRÉ-REQUISITOS

### Ferramentas Locais
- **AWS CLI** v2.x configurado
- **Terraform** v1.12+
- **kubectl** v1.28+
- **Docker** Desktop
- **Git**
- Conta GitHub
- Conta AWS (com permissões administrativas)

### Contas Necessárias
- ✅ **AWS Account** - Para provisionar infraestrutura
- ✅ **GitHub Account** - Para CI/CD pipelines
- ✅ **Docker Hub Account** (gratuito) - Para armazenar imagens

---

## 🔧 PASSO 1: CLONAR O PROJETO

```bash
git clone https://github.com/jlui70/gitops-eks.git
cd gitops-eks
```

---

## 🔑 PASSO 2: CONFIGURAR CREDENCIAIS AWS LOCAIS

```bash
# Configurar AWS CLI com suas credenciais
aws configure

# Inserir:
# - AWS Access Key ID: <SUA_ACCESS_KEY>
# - AWS Secret Access Key: <SUA_SECRET_KEY>
# - Default region: us-east-1
# - Default output: json

# Verificar
aws sts get-caller-identity
```

**Saída esperada:**
```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",  ← SEU AWS ACCOUNT ID
    "Arn": "arn:aws:iam::123456789012:user/SEU-USUARIO"
}
```

⚠️ **Anote o `Account ID` - você vai precisar!**

---

## 🏗️ PASSO 3: PROVISIONAR INFRAESTRUTURA AWS

### 3.1. Criar Backend Terraform (S3 + DynamoDB)

```bash
cd 00-backend
terraform init
terraform plan
terraform apply -auto-approve
cd ..
```

### 3.2. Criar Networking (VPC, Subnets, NAT Gateways)

```bash
cd 01-networking
terraform init
terraform plan
terraform apply -auto-approve
cd ..
```

### 3.3. Criar EKS Cluster

```bash
cd 02-eks-cluster
terraform init
terraform plan
terraform apply -auto-approve
cd ..
```

⏱️ **Tempo total:** ~20-25 minutos

### 3.4. Configurar kubectl

```bash
aws eks update-kubeconfig \
  --name eks-devopsproject-cluster \
  --region us-east-1

# Verificar
kubectl get nodes
```

---

## 🐳 PASSO 4: CONFIGURAR DOCKER HUB

### 4.1. Criar Conta Docker Hub

1. Acesse: https://hub.docker.com/signup
2. Crie uma conta gratuita (ex: `seu-usuario`)

### 4.2. Fazer Login Local

```bash
docker login -u seu-usuario
# Inserir senha quando solicitado
```

### 4.3. Preparar Imagens

**OPÇÃO A - Usar Imagens Existentes (Mais Rápido):**

```bash
# Pull das imagens públicas
for service in ecommerce-ui product-catalog order-management product-inventory profile-management shipping-and-handling contact-support-team; do
  docker pull rslim087/$service:latest
  docker tag rslim087/$service:latest seu-usuario/$service:latest
  docker push seu-usuario/$service:latest
done
```

**OPÇÃO B - Build Local (Se tiver os Dockerfiles):**

```bash
cd 06-ecommerce-app/microservices

for service in ecommerce-ui product-catalog order-management product-inventory profile-management shipping-and-handling contact-support-team; do
  docker build -t seu-usuario/$service:latest $service/
  docker push seu-usuario/$service:latest
done
```

---

## 🔐 PASSO 5: CRIAR USUÁRIO IAM PARA GITHUB ACTIONS

```bash
cd scripts
./setup-github-actions-iam.sh
```

**O script vai gerar 3 credenciais. COPIE e GUARDE:**

```
AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: ****...
AWS_ACCOUNT_ID: 123456789012
```

⚠️ **ATENÇÃO:** Essas credenciais aparecem apenas UMA VEZ!

---

## 📦 PASSO 6: CRIAR REPOSITÓRIOS ECR

```bash
cd scripts
./setup-ecr.sh
```

Isso cria 7 repositórios privados no Amazon ECR para armazenar as imagens.

---

## 🔧 PASSO 7: ATUALIZAR CONFIGURAÇÕES DO PROJETO

### 7.1. Atualizar Workflow CI

Edite: `.github/workflows/ci.yml`

**Linha ~145 - Substituir `luiz7030` pelo SEU usuário Docker Hub:**

```yaml
# ANTES:
docker pull luiz7030/${{ matrix.service }}:latest

# DEPOIS:
docker pull SEU-USUARIO/${{ matrix.service }}:latest
```

**Linha ~151 - Mesma alteração:**

```yaml
# ANTES:
docker tag luiz7030/${{ matrix.service }}:latest $IMAGE_URI

# DEPOIS:
docker tag SEU-USUARIO/${{ matrix.service }}:latest $IMAGE_URI
```

### 7.2. Atualizar Account ID (se necessário)

Procure por `794038226274` no projeto e substitua pelo **SEU Account ID**:

```bash
# Encontrar ocorrências
grep -r "794038226274" .

# Arquivos que podem precisar atualizar:
# - .github/workflows/ci.yml
# - .github/workflows/cd.yml
# - scripts/setup-ecr.sh
```

---

## 🐙 PASSO 8: CONFIGURAR REPOSITÓRIO GITHUB

### 8.1. Criar Novo Repositório

1. Acesse: https://github.com/new
2. Nome: `gitops-eks` (ou qualquer outro)
3. Deixe **privado** ou **público** (sua escolha)
4. **NÃO inicialize** com README

### 8.2. Push do Código

```bash
# Se ainda não configurou remote
git remote remove origin  # Remove o remote antigo
git remote add origin https://github.com/SEU-USUARIO/gitops-eks.git

# Push
git push -u origin main
```

### 8.3. Configurar GitHub Secrets

1. Vá em: `Settings → Environments → New environment`
2. Nome: `production`
3. Click em `Add secret` e adicione os 3 secrets:

**Secret 1:**
```
Name: AWS_ACCESS_KEY_ID
Value: AKIA... (do Passo 5)
```

**Secret 2:**
```
Name: AWS_SECRET_ACCESS_KEY
Value: ****... (do Passo 5)
```

**Secret 3:**
```
Name: AWS_ACCOUNT_ID
Value: 123456789012 (seu Account ID)
```

---

## 🚀 PASSO 9: DEPLOY DA APLICAÇÃO v1

```bash
cd 06-ecommerce-app
./deploy.sh
```

Aguarde os pods ficarem prontos (~2-3 min).

### Verificar

```bash
kubectl get pods -n ecommerce
kubectl get ingress ecommerce-ingress -n ecommerce
```

Acesse a URL do ALB no navegador.

---

## 🧪 PASSO 10: TESTAR CI/CD

### 10.1. Testar CI (Automático)

```bash
# Fazer uma alteração
echo "# Test CI/CD - $(date)" >> 06-ecommerce-app/README.md

# Commit e push
git add .
git commit -m "test: trigger CI pipeline"
git push origin main
```

Acompanhe em: `https://github.com/SEU-USUARIO/gitops-eks/actions`

### 10.2. Testar CD (Manual)

1. GitHub → Actions → **"CD - Deploy to EKS"**
2. **Run workflow**
3. Configurar:
   - Environment: `production`
   - Version: `latest`
   - Deployment strategy: `blue-green`
4. Click **"Run workflow"**

### 10.3. Verificar Deploy v2

```bash
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version
kubectl get service ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'
```

---

## 🔄 PASSO 11: TESTAR ROLLBACK

### Via Comando (Mais Rápido)

```bash
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'
```

### Via GitHub Actions

1. Actions → **"Rollback Deployment"**
2. **Run workflow**

---

## 📊 CUSTOS AWS

### Estimativa Mensal (24/7)
- **EKS Cluster:** ~$73/mês
- **EC2 (3x t3.medium):** ~$90/mês
- **NAT Gateways (2x):** ~$65/mês
- **ALB:** ~$18/mês
- **Total:** ~$246/mês

### 💡 ECONOMIA

Para laboratório/testes, use apenas algumas horas:

```bash
# Após terminar os testes
cd scripts
./destroy-all.sh

# Custos após destruir: $0/mês
```

⏱️ **Sugestão:** Use 2-4 horas (~$2-4 total)

---

## 🗑️ DESTRUIR INFRAESTRUTURA

### Método Rápido (Script Automatizado)

```bash
cd scripts
./destroy-all.sh
```

### Método Manual (Ordem Inversa)

```bash
# 1. Deletar aplicação
kubectl delete namespace ecommerce

# 2. Destruir EKS
cd 02-eks-cluster
terraform destroy -auto-approve

# 3. Destruir Networking
cd ../01-networking
terraform destroy -auto-approve

# 4. Destruir Backend (ÚLTIMO!)
cd ../00-backend
terraform destroy -auto-approve
```

⚠️ **IMPORTANTE:** Destrua na ordem inversa da criação!

---

## 🔧 PERSONALIZAÇÃO (OPCIONAL)

### Alterar Nome do Cluster

Edite: `02-eks-cluster/locals.tf`

```hcl
locals {
  cluster_name = "meu-cluster-eks"  # ← Alterar aqui
}
```

### Alterar Região AWS

Edite em **TODOS** os arquivos `main.tf`:

```hcl
provider "aws" {
  region = "us-west-2"  # ← Alterar de us-east-1
}
```

### Usar Domínio Próprio (Route53)

1. Registre um domínio no Route53
2. Edite: `02-eks-cluster/route53.hosted-zone.tf`
3. Altere a zona hospedada para seu domínio

---

## 📚 ESTRUTURA DO PROJETO

```
gitops-eks/
├── 00-backend/          # S3 + DynamoDB (Terraform state)
├── 01-networking/       # VPC, Subnets, NAT Gateways
├── 02-eks-cluster/      # EKS Cluster + Node Group + Add-ons
├── 06-ecommerce-app/    # Aplicação de demonstração
│   ├── manifests/       # Kubernetes manifests v1
│   ├── manifests-v2/    # Kubernetes manifests v2 (Blue/Green)
│   └── microservices/   # Dockerfiles dos 7 microserviços
├── .github/workflows/   # CI/CD pipelines
│   ├── ci.yml          # Build & Test
│   ├── cd.yml          # Deploy to EKS
│   └── rollback.yml    # Rollback deployment
└── scripts/            # Scripts de automação
    ├── setup-ecr.sh
    ├── setup-github-actions-iam.sh
    ├── rebuild-all.sh
    └── destroy-all.sh
```

---

## ❓ TROUBLESHOOTING

### CI falha com "The security token is invalid"
→ Verifique se os GitHub Secrets estão corretos
→ Recrie o usuário IAM: `./scripts/setup-github-actions-iam.sh`

### CD falha com "Unauthorized"
→ Execute: `./scripts/update-aws-auth.sh`
→ Isso adiciona o usuário github-actions-eks ao cluster

### Pods ficam em "ImagePullBackOff"
→ Verifique se as imagens estão no Docker Hub: `docker search seu-usuario/ecommerce-ui`
→ Ou no ECR: `aws ecr describe-images --repository-name ecommerce/ecommerce-ui`

### ALB não cria / Ingress sem IP
→ Verifique os logs do ALB controller: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

### "Error from server (NotFound): namespaces ecommerce not found"
→ Execute o deploy da aplicação: `cd 06-ecommerce-app && ./deploy.sh`

---

## 🆘 SUPORTE

- **Issues:** https://github.com/jlui70/gitops-eks/issues
- **Documentação AWS EKS:** https://docs.aws.amazon.com/eks/
- **Documentação Terraform:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

## 📝 CHECKLIST DE VALIDAÇÃO

Antes de considerar o setup completo, verifique:

- [ ] AWS CLI configurado e funcionando
- [ ] Terraform provisionou as 3 stacks sem erro
- [ ] kubectl conecta ao cluster EKS
- [ ] 3 nodes aparecem em `kubectl get nodes`
- [ ] Imagens estão no Docker Hub (7 imagens)
- [ ] Repositórios ECR criados (7 repositórios)
- [ ] GitHub Secrets configurados (3 secrets)
- [ ] Usuário IAM github-actions-eks existe
- [ ] Aplicação v1 rodando no cluster
- [ ] CI pipeline executou com sucesso
- [ ] CD pipeline executou com sucesso
- [ ] Blue/Green deployment funcionando
- [ ] Rollback funcionando

---

## 🎯 PRÓXIMOS PASSOS

Após o setup completo:

1. ✅ Revise o [GUIA-APRESENTACAO.md](../GUIA-APRESENTACAO.md) para preparar sua demo
2. ✅ Teste o fluxo CI/CD completo 2-3 vezes
3. ✅ Prepare a aplicação em um browser para mostrar a diferença v1/v2
4. ✅ Tenha comandos prontos em um arquivo de texto para copiar/colar durante apresentação

---

## 📄 LICENÇA

MIT License - Use livremente, contribua, e compartilhe!

---

**Desenvolvido por:** [DevOps Project](https://devopsproject.com.br)  
**GitHub:** [@jlui70](https://github.com/jlui70)  
**Última atualização:** 27/01/2026
