# 🚀 CI/CD Pipeline - GitHub Actions

## 📋 Visão Geral

Este projeto implementa um **pipeline CI/CD completo** usando **GitHub Actions** para deployment automatizado no Amazon EKS com estratégia **Blue/Green**.

---

## 🏗️ Arquitetura CI/CD

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPER WORKFLOW                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ git push
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  GitHub Repository (main)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
            ┌───────────┴────────────┐
            │                        │
            ▼                        ▼
┌───────────────────────┐  ┌──────────────────────┐
│   CI Workflow         │  │  Manual Trigger      │
│   (Automatic)         │  │  (workflow_dispatch) │
├───────────────────────┤  └──────────────────────┘
│ 1. Validate manifests │            │
│ 2. Build images       │            │
│ 3. Push to ECR        │            │
│ 4. Run tests          │            │
│ 5. Security scan      │            │
└───────────┬───────────┘            │
            │                        │
            └────────────┬───────────┘
                         ▼
            ┌────────────────────────┐
            │   CD Workflow          │
            ├────────────────────────┤
            │ 1. Update kubeconfig   │
            │ 2. Deploy v2 (Green)   │
            │ 3. Health check        │
            │ 4. Switch traffic      │
            │ 5. Verify deployment   │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Amazon EKS Cluster    │
            ├────────────────────────┤
            │  ┌──────────────────┐  │
            │  │  v1 (Blue)       │  │
            │  └──────────────────┘  │
            │  ┌──────────────────┐  │
            │  │  v2 (Green) ✅   │  │
            │  └──────────────────┘  │
            └────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │     Production         │
            │ eks.devopsproject.com  │
            └────────────────────────┘
```

---

## 📁 Estrutura dos Workflows

```
.github/workflows/
├── ci.yml         # Continuous Integration
├── cd.yml         # Continuous Deployment
└── rollback.yml   # Rollback automático
```

---

## 🔄 Workflow 1: CI (Continuous Integration)

**Arquivo:** `.github/workflows/ci.yml`

### Triggers:
- ✅ Push para `main` ou `develop`
- ✅ Pull Request para `main` ou `develop`
- ✅ Mudanças em `06-ecommerce-app/**`

### Jobs:

#### 1️⃣ **Validate**
- Valida sintaxe dos manifests Kubernetes
- Valida configuração NGINX
- Executa `kubectl apply --dry-run`

#### 2️⃣ **Build**
- Login no Amazon ECR
- Cria repositórios ECR (se não existirem)
- Build de imagens Docker para 7 microserviços
- Push para ECR com tags: `<git-sha>` e `latest`
- Scan de vulnerabilidades

#### 3️⃣ **Test**
- Testa configuração NGINX
- Valida manifests com dry-run
- Executa testes unitários

#### 4️⃣ **Summary**
- Gera relatório de build
- Exibe status de todos os jobs

### Exemplo de execução:
```bash
# Automaticamente ao fazer push
git add .
git commit -m "feat: update ecommerce-ui"
git push origin main

# CI workflow executa automaticamente
```

---

## 🚀 Workflow 2: CD (Continuous Deployment)

**Arquivo:** `.github/workflows/cd.yml`

### Triggers:
- ✅ Manual via `workflow_dispatch`
- ✅ Após sucesso do CI workflow
- ✅ Push para `main`

### Inputs (Manual):
- `environment`: production | staging
- `version`: latest | specific tag
- `deployment_strategy`: blue-green | rolling | canary

### Jobs:

#### 1️⃣ **Deploy**
- Configura AWS credentials
- Atualiza kubeconfig do EKS
- Login no ECR
- Deploy v2 (Blue/Green):
  - Apply ConfigMap NGINX
  - Deploy backend v2
  - Deploy proxy v2
- Aguarda pods ficarem prontos
- Health check v2
- **Switch de tráfego** (v1 → v2)
- Verifica deployment

#### 2️⃣ **Notify**
- Notifica sucesso/falha
- Exibe URL da aplicação

### Exemplo de execução manual:

**Via GitHub UI:**
1. Vá em **Actions** → **CD - Deploy to EKS**
2. Clique em **Run workflow**
3. Selecione:
   - Environment: `production`
   - Version: `latest`
   - Strategy: `blue-green`
4. Clique em **Run workflow**

---

## 🔙 Workflow 3: Rollback

**Arquivo:** `.github/workflows/rollback.yml`

### Triggers:
- ✅ Manual via `workflow_dispatch` apenas

### Inputs:
- `reason`: Motivo do rollback (obrigatório)
- `target_version`: v1 | v2
- `cleanup_failed_version`: true | false

### Jobs:

#### 1️⃣ **Rollback**
- Exibe status pré-rollback
- **Switch de tráfego** para versão alvo
- Verifica rollback
- Opcional: Remove recursos da versão falha
- Exibe status pós-rollback

#### 2️⃣ **Notify**
- Notifica sucesso/falha do rollback

### Exemplo de execução:

**Via GitHub UI:**
1. Vá em **Actions** → **Rollback Deployment**
2. Clique em **Run workflow**
3. Preencha:
   - Reason: `High error rate in v2`
   - Target version: `v1`
   - Cleanup: `false` (manter v2 para análise)
4. Clique em **Run workflow**

**Tempo de rollback:** < 30 segundos ⚡

---

## 🔐 Secrets Necessários

Configure no GitHub: **Settings** → **Secrets and variables** → **Actions**

### Required Secrets:
```bash
AWS_ACCESS_KEY_ID       # IAM User Access Key
AWS_SECRET_ACCESS_KEY   # IAM User Secret Key
AWS_ACCOUNT_ID          # 794038226274
```

### Como criar IAM User para GitHub Actions:

```bash
# 1. Criar IAM Policy
aws iam create-policy \
  --policy-name GitHubActionsEKSPolicy \
  --policy-document file://iam-policy.json

# 2. Criar IAM User
aws iam create-user --user-name github-actions-eks

# 3. Attach policy
aws iam attach-user-policy \
  --user-name github-actions-eks \
  --policy-arn arn:aws:iam::794038226274:policy/GitHubActionsEKSPolicy

# 4. Criar Access Key
aws iam create-access-key --user-name github-actions-eks
```

**IAM Policy necessária:**
- `eks:DescribeCluster`
- `eks:UpdateClusterConfig`
- `ecr:*` (Full ECR access)
- `sts:GetCallerIdentity`

---

## 📦 Setup Amazon ECR

Antes de usar CI/CD, crie repositórios ECR:

```bash
cd /home/luiz7/Projects/gitops
./scripts/setup-ecr.sh
```

**O que o script faz:**
- ✅ Cria 7 repositórios ECR (um por microserviço)
- ✅ Habilita scan de vulnerabilidades
- ✅ Configura encriptação AES256

**Repositórios criados:**
```
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/ecommerce-ui
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/product-catalog
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/order-management
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/product-inventory
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/profile-management
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/shipping-and-handling
794038226274.dkr.ecr.us-east-1.amazonaws.com/ecommerce/contact-support-team
```

---

## 🎯 Fluxo Completo de Deployment

### 1. Desenvolvimento Local
```bash
# Fazer mudanças no código/manifests
vim 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml

# Commit
git add .
git commit -m "feat: update banner text"
git push origin main
```

### 2. CI Pipeline (Automático)
- ✅ Valida manifests
- ✅ Build imagens Docker
- ✅ Push para ECR
- ✅ Testes

**Duração:** ~5-10 minutos

### 3. CD Pipeline (Manual)
```bash
# Via GitHub UI: Actions → CD - Deploy to EKS → Run workflow
```
- ✅ Deploy v2 (Green)
- ✅ Health check
- ✅ Switch tráfego
- ✅ Validação

**Duração:** ~3-5 minutos

### 4. Monitoramento
```bash
# Ver logs dos pods
kubectl logs -n ecommerce -l version=v2 --tail=100 -f

# Ver métricas
kubectl top pods -n ecommerce

# Acessar aplicação
curl http://eks.devopsproject.com.br/api/version
```

### 5. Rollback (se necessário)
```bash
# Via GitHub UI: Actions → Rollback Deployment → Run workflow
# Reason: "High error rate"
# Target: v1
```

**Duração:** ~30 segundos ⚡

---

## 🧪 Testes Locais

### Testar CI localmente (act):
```bash
# Instalar act
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Executar CI localmente
act push -W .github/workflows/ci.yml
```

### Testar manifests:
```bash
kubectl apply --dry-run=client -f 06-ecommerce-app/manifests-v2/
```

### Testar NGINX config:
```bash
docker run --rm -v $PWD/06-ecommerce-app/manifests-v2:/manifests \
  nginx:1.25-alpine nginx -t -c /manifests/configmap-nginx-v2.yaml
```

---

## 📊 Métricas e Monitoramento

### GitHub Actions Insights:
- **Actions** → **Workflows** → Ver histórico
- Tempo médio de execução
- Taxa de sucesso/falha

### Kubernetes Metrics:
```bash
# Pods por versão
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version

# CPU/Memory
kubectl top pods -n ecommerce

# Logs
kubectl logs -n ecommerce -l version=v2 --tail=50
```

---

## 🔒 Segurança

### Scan de Vulnerabilidades:
- ✅ ECR scan automático ao push
- ✅ Scan durante CI pipeline

### Verificar vulnerabilidades:
```bash
aws ecr describe-image-scan-findings \
  --repository-name ecommerce/ecommerce-ui \
  --image-id imageTag=latest \
  --region us-east-1
```

### Secrets Management:
- ✅ GitHub Secrets (não expostos em logs)
- ✅ AWS IAM com least privilege
- ✅ Sem hardcode de credentials

---

## 🐛 Troubleshooting

### Pipeline falha no build:
```bash
# Verificar logs do GitHub Actions
# Verificar ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 794038226274.dkr.ecr.us-east-1.amazonaws.com
```

### Deploy falha:
```bash
# Verificar kubectl config
kubectl cluster-info

# Verificar pods
kubectl get pods -n ecommerce -o wide

# Ver eventos
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

### Rollback não funciona:
```bash
# Verificar service selector
kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 2 selector

# Forçar patch
kubectl patch svc ecommerce-ui -n ecommerce -p '{"spec":{"selector":{"version":"v1"}}}'
```

---

## 📈 Melhorias Futuras

- [ ] Testes de integração automatizados
- [ ] Canary deployment (5% → 50% → 100%)
- [ ] Smoke tests após deployment
- [ ] Notificações Slack/Discord
- [ ] Prometheus + Grafana dashboards
- [ ] GitOps com ArgoCD
- [ ] Multi-region deployment

---

## 📝 Checklist para Produção

Antes de usar em produção:

- [ ] ✅ ECR repositórios criados
- [ ] ✅ GitHub Secrets configurados
- [ ] ✅ IAM User com permissões corretas
- [ ] ✅ EKS cluster acessível
- [ ] ✅ DNS configurado
- [ ] ✅ v1 rodando e estável
- [ ] ✅ Testar CI pipeline
- [ ] ✅ Testar CD pipeline
- [ ] ✅ Testar rollback
- [ ] ✅ Documentar runbook

---

## 🎓 Recursos Adicionais

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Amazon EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Blue/Green Deployments](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_tracking_change_management_blue_green_deployments.html)
- [ECR User Guide](https://docs.aws.amazon.com/ecr/)

---

✅ **Pipeline CI/CD pronto para uso!**
