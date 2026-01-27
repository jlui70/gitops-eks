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

### Opção Recomendada: Script Automatizado

```bash
# Provisiona TUDO de uma vez (Backend + Networking + EKS)
./scripts/rebuild-all.sh
```

⏱️ **Tempo total:** ~20-25 minutos

O script cria automaticamente:
- ✅ Stack 00: Backend (S3 + DynamoDB)
- ✅ Stack 01: Networking (VPC + Subnets + NAT Gateways)
- ✅ Stack 02: EKS Cluster (Cluster + Node Group + ALB Controller)

### Opção Manual (Passo a Passo)

Se preferir executar manualmente:

```bash
# 1. Backend
cd 00-backend
terraform init && terraform apply -auto-approve
cd ..

# 2. Networking
cd 01-networking
terraform init && terraform apply -auto-approve
cd ..

# 3. EKS Cluster
cd 02-eks-cluster
terraform init && terraform apply -auto-approve
cd ..
```

### Configurar kubectl

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
# Pull das imagens do repositório de referência
for service in ecommerce-ui product-catalog order-management product-inventory profile-management shipping-and-handling contact-support-team; do
  docker pull luiz7030/$service:latest
  docker tag luiz7030/$service:latest seu-usuario/$service:latest
  docker push seu-usuario/$service:latest
done
```

⚠️ **Nota:** Usamos `luiz7030` como repositório de referência. Se essas imagens não estiverem disponíveis no futuro, use a OPÇÃO B (build local).

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

## 📄 LICENÇA

MIT License - Use livremente, contribua, e compartilhe!

---

**Desenvolvido por:** [DevOps Project](https://devopsproject.com.br)  
**GitHub:** [@jlui70](https://github.com/jlui70)  
**Última atualização:** 27/01/2026
