# 🎯 Guia de Apresentação - Pipeline CI/CD

## 📋 Índice
1. [Configuração CD Manual vs Automático](#configuração-cd-manual-vs-automático)
2. [Como Simular Atualizações de Versão](#como-simular-atualizações-de-versão)
3. [Fluxo Completo para Apresentação](#fluxo-completo-para-apresentação)
4. [Validação e Testes](#validação-e-testes)

---

## 🔧 Configuração CD Manual vs Automático

### Modo Atual: MANUAL (Recomendado para Apresentação)

O CD está configurado para executar **apenas manualmente** via GitHub Actions UI.

**Arquivo**: `.github/workflows/cd.yml`

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'production'
        ...

  # CD Automático DESABILITADO - Deploy manual via GitHub Actions UI
  # workflow_run:
  #   workflows: ["CI - Build and Test"]
  #   types: [completed]
  #   branches: [main]
```

### Para Habilitar CD Automático

Descomente as linhas no arquivo `.github/workflows/cd.yml`:

```yaml
on:
  workflow_dispatch:
    inputs: ...

  workflow_run:
    workflows: ["CI - Build and Test"]
    types:
      - completed
    branches:
      - main
```

**Commit e push:**
```bash
git add .github/workflows/cd.yml
git commit -m "ci: enable automatic CD after CI success"
git push
```

### Quando usar cada modo?

| Modo | Quando Usar | Vantagens |
|------|-------------|-----------|
| **Manual** | Apresentações, Produção Crítica | Controle total, Aprovação humana, Melhor para demonstrações |
| **Automático** | Desenvolvimento, Staging | Deploy rápido, Menos intervenção, CI/CD completo |

---

## 🎨 Como Simular Atualizações de Versão

### Arquivo a Editar
**Caminho**: `06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml`

### Estrutura do Banner

```yaml
sub_filter '</body>' '
    <div style="position: fixed; top: 0; left: 0; right: 0; 
                background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); 
                color: white; padding: 15px; text-align: center; 
                font-family: Arial, sans-serif; font-weight: bold; 
                font-size: 18px; z-index: 9999; 
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        ✅ VERSION 2.1 - BUGS FIXED & PERFORMANCE IMPROVED! ✅
    </div>
```

### Exemplos de Versões para Simular

#### Versão 2.2 - Nova Feature
```yaml
# Banner AZUL
background: linear-gradient(135deg, #2193b0 0%, #6dd5ed 100%);
🎉 VERSION 2.2 - NEW DASHBOARD AVAILABLE! 🎉
```

```yaml
# API endpoint
return 200 '{"version": "2.2", "status": "active", "features": ["new-ui", "improved-performance", "enhanced-security", "bug-fixes", "new-dashboard"]}';
```

#### Versão 2.3 - Hotfix Crítico
```yaml
# Banner LARANJA/AMARELO
background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
🔥 VERSION 2.3 - CRITICAL SECURITY PATCH! 🔥
```

```yaml
# API endpoint
return 200 '{"version": "2.3", "status": "active", "features": ["new-ui", "improved-performance", "enhanced-security", "bug-fixes", "new-dashboard", "security-patch"]}';
```

#### Versão 3.0 - Major Release
```yaml
# Banner ROXO/ROSA
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
🚀 VERSION 3.0 - COMPLETE REDESIGN! 🚀
```

```yaml
# API endpoint
return 200 '{"version": "3.0", "status": "active", "features": ["redesigned-ui", "ai-powered", "real-time-analytics", "mobile-app"]}';
```

### Paleta de Cores para Banners

```css
/* Verde - Sucesso/Correções */
background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);

/* Azul - Novas Features */
background: linear-gradient(135deg, #2193b0 0%, #6dd5ed 100%);

/* Roxo - Major Release */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Laranja - Hotfix/Urgente */
background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);

/* Vermelho - Crítico */
background: linear-gradient(135deg, #eb3349 0%, #f45c43 100%);
```

---

## 🎬 Fluxo Completo para Apresentação

### Cenário 1: Deploy de Nova Versão (v2.2)

#### 1. Preparar a Mudança
```bash
cd /home/luiz7/Projects/gitops
vim 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml
```

Altere:
- Banner: "VERSION 2.2 - NEW DASHBOARD AVAILABLE!"
- Cor: Azul (`#2193b0` → `#6dd5ed`)
- API: version "2.2" com feature "new-dashboard"

#### 2. Commit e Push
```bash
git add 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml
git commit -m "feat: release v2.2 with new dashboard feature"
git push
```

#### 3. Aguardar CI Pipeline
- Acesse: https://github.com/jlui70/gitops-eks/actions
- Aguarde workflow **"CI - Build and Test"** completar (30-60s)
- **Mostre na apresentação**: "CI validou os manifestos ✅"

#### 4. Executar CD Pipeline Manualmente
- No GitHub Actions, clique em **"CD - Deploy to EKS"**
- Clique em **"Run workflow"** (canto superior direito)
- Preencha:
  - **environment**: `production`
  - **version**: `latest`
  - **deployment_strategy**: `blue-green`
- **Mostre na apresentação**: "Aprovando deploy manualmente 👍"

#### 5. Aguardar CD Completar
- Acompanhe os logs do workflow (30-40s)
- **Mostre**: Deploy v2.2 ✅ → Traffic Switched ✅

#### 6. Validar no Navegador
```bash
# Abra no navegador
http://eks.devopsproject.com.br
```
- **Mostre**: Banner AZUL com "VERSION 2.2"

### Cenário 2: Rollback por Problema

#### 1. Identificar Problema (Simulado)
**Fale**: "Detectamos um problema na v2.2, vamos fazer rollback!"

#### 2. Executar Rollback
- GitHub Actions → **"Rollback Deployment"** → **"Run workflow"**
- Preencha:
  - **reason**: `Critical bug found in v2.2 - rolling back to v2.1`
  - **target_version**: `v2.1` (ou `v1` se preferir)
  - **cleanup_failed_version**: `false`
- **Mostre**: "Rollback em < 30 segundos! ⚡"

#### 3. Validar Rollback
```bash
# Verificar serviço
kubectl get service ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'
# Resultado: {"app":"ecommerce-ui","version":"v2.1"}

# Testar no navegador
http://eks.devopsproject.com.br
```
- **Mostre**: Banner voltou para v2.1 (verde)

### Cenário 3: Hotfix Urgente (v2.3)

#### 1. Fazer Correção
```bash
vim 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml
```
Altere para v2.3 (banner laranja, "CRITICAL SECURITY PATCH!")

#### 2. Deploy Rápido
```bash
git add 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml
git commit -m "hotfix: v2.3 critical security patch"
git push
```

#### 3. Executar CI/CD
- **Fale**: "Hotfix crítico! CI valida → Aprovo CD → Deploy!"
- Execute CD manualmente após CI passar
- **Mostre**: "Hotfix em produção em < 2 minutos! 🔥"

---

## ✅ Validação e Testes

### Verificar Versão Ativa

#### Via kubectl
```bash
# Ver serviço
kubectl get service ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' && echo ""

# Ver pods rodando
kubectl get pods -n ecommerce -l app=ecommerce-ui

# Ver versão via API
kubectl exec -n ecommerce deployment/ecommerce-ui-v2 -- \
  wget -qO- http://localhost:4000/api/version
```

#### Via Browser
```bash
# Abrir aplicação
http://eks.devopsproject.com.br

# API de versão
http://eks.devopsproject.com.br/api/version
```

#### Via curl
```bash
# Testar banner visível
curl -s http://eks.devopsproject.com.br | grep -i "version"

# API JSON
curl -s http://eks.devopsproject.com.br/api/version | jq
```

### Comandos Rápidos para Apresentação

```bash
# Status geral do cluster
kubectl get all -n ecommerce

# Histórico de deployments
kubectl rollout history deployment ecommerce-ui-v2 -n ecommerce

# Logs em tempo real
kubectl logs -f deployment/ecommerce-ui-v2 -n ecommerce

# Eventos recentes
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

### Checklist de Apresentação

- [ ] Cluster EKS rodando
- [ ] v1 (ou versão anterior) ativa
- [ ] GitHub Actions configurado
- [ ] Terminal aberto com kubectl configurado
- [ ] Navegador em http://eks.devopsproject.com.br
- [ ] GitHub Actions aberto em https://github.com/jlui70/gitops-eks/actions

### Roteiro Sugerido (10 minutos)

1. **Introdução** (1 min)
   - Mostrar arquitetura: AWS EKS + GitHub Actions + Blue/Green
   
2. **Status Atual** (1 min)
   - Mostrar aplicação rodando (v1 ou v2.1)
   - Mostrar pods no cluster
   
3. **Simular Nova Feature** (3 min)
   - Editar configmap (v2.2)
   - Commit e push
   - Mostrar CI rodando automaticamente
   
4. **Aprovar Deploy** (2 min)
   - CI passou ✅
   - Executar CD manualmente (mostrar controle)
   - Aguardar deploy Blue/Green
   
5. **Validar Deployment** (1 min)
   - Mostrar novo banner (v2.2)
   - Mostrar pods rodando
   
6. **Demonstrar Rollback** (2 min)
   - Executar rollback para versão anterior
   - Validar que voltou (< 30s)
   - Mostrar zero downtime

---

## 🚀 Comandos Rápidos

### Atualizar Banner
```bash
# Editar
vim 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml

# Commit
git add 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml
git commit -m "feat: release vX.X with <feature>"
git push
```

### Deploy Manual
```bash
# Via GitHub Actions UI
# https://github.com/jlui70/gitops-eks/actions
# → CD - Deploy to EKS → Run workflow
```

### Rollback Rápido
```bash
# Via kubectl (emergência)
kubectl patch service ecommerce-ui -n ecommerce -p '{"spec":{"selector":{"version":"v1"}}}'

# Via GitHub Actions (recomendado para apresentação)
# → Rollback Deployment → Run workflow
```

### Verificar Status
```bash
# Versão ativa
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'

# Testar endpoint
curl -s http://eks.devopsproject.com.br | grep -i version
```

---

## 📝 Notas Importantes

1. **CD Manual vs Automático**: Atualmente configurado para MANUAL (melhor para apresentações)
2. **Tempo de Deploy**: ~30-40 segundos (Blue/Green)
3. **Tempo de Rollback**: < 30 segundos
4. **Zero Downtime**: Ambos v1 e v2 ficam rodando durante transição
5. **Auditoria**: Todos os deploys ficam registrados no GitHub Actions

---

## 🎯 Mensagens Chave para Apresentação

- ✅ "CI valida automaticamente cada commit"
- 👍 "CD requer aprovação manual em produção"
- ⚡ "Deploy Blue/Green com zero downtime"
- 🔙 "Rollback em menos de 30 segundos"
- 📊 "Auditoria completa no GitHub"
- 🔒 "IAM e RBAC configurados para segurança"

---

**Data de Criação**: Janeiro 16, 2026  
**Última Atualização**: Janeiro 16, 2026
