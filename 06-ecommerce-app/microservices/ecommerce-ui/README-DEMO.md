# 🎯 GitOps Demo - Estrutura de Arquivos

Este diretório contém todos os arquivos necessários para executar a demonstração GitOps completa.

---

## 📁 Estrutura Criada para a Demo

```
microservices/ecommerce-ui/
├── Dockerfile                    # Build da aplicação React
├── nginx.conf                    # Configuração do servidor web
├── package.json                  # Dependências Node.js
└── src/                          # Código fonte React
    ├── App.js                    # Componente principal
    ├── App.css                   # Estilos globais
    ├── index.js                  # Entry point
    ├── index.css                 # Estilos base
    ├── components/               # Componentes reutilizáveis
    └── pages/
        ├── Home.js              # ⭐ PÁGINA MODIFICADA NA DEMO
        ├── Home.js.v1-original  # Backup da versão original
        ├── Home.css             # Estilos da página inicial
        ├── ProductList.js       # Catálogo de produtos
        ├── ProductDetail.js     # Detalhes do produto
        ├── AuthPage.js          # Login/Register
        ├── Profile.js           # Perfil do usuário
        ├── Contact.js           # Suporte
        ├── ShippingHandling.js  # Shipping calculator
        ├── Inventory.js         # Gestão de estoque
        └── Orders.js            # Gerenciamento de pedidos
```

---

## 📚 Guias de Demonstração

### **🚀 [ROTEIRO-APRESENTACAO.md](../ROTEIRO-APRESENTACAO.md)**
Roteiro completo com 3 opções de demo:
- Demo completa passo a passo (10 min)
- Demo rápida para apresentação (5 min) ⭐ RECOMENDADO
- Demo manual para experts (8 min)

### **🎤 [TALKING-POINTS.md](../TALKING-POINTS.md)**
Script de apresentação com:
- Narrativa completa para cada parte
- Frases-chave para memorizar
- Respostas para perguntas frequentes
- Tips de apresentação

### **📋 [DEMO-CHEAT-SHEET.md](../DEMO-CHEAT-SHEET.md)**
Referência rápida para imprimir:
- Comandos essenciais
- Troubleshooting
- Checklist pré-demo
- Timeline visual

### **📖 [DEMO-GITOPS-FLOW.md](../DEMO-GITOPS-FLOW.md)**
Guia técnico detalhado:
- Fluxo completo de GitOps
- Explicação de cada componente
- Comparação antes vs depois
- Arquitetura visual

---

## 🎬 Scripts de Automação

### **1. Script Completo** (Interativo, educacional)
```bash
./scripts/demo-gitops-update.sh
```

**Características:**
- ✅ Mostra cada passo claramente
- ✅ Pausa para explicações
- ✅ Output colorido e formatado
- ✅ Perfeito para demonstrações ao vivo
- ⏱️ Tempo: ~10 minutos

**Quando usar:**
- Apresentações técnicas detalhadas
- Workshops hands-on
- Training sessions
- Quando tem tempo para explicar conceitos

---

### **2. Script Rápido** ⭐ (Automatizado, ágil)
```bash
./scripts/demo-quick.sh
```

**Características:**
- ✅ Execução automática
- ✅ Output conciso
- ✅ Build silencioso (no verbose)
- ✅ Ideal para demos ao vivo
- ⏱️ Tempo: ~5 minutos

**Quando usar:**
- Apresentações executivas
- Demos com tempo limitado
- Pitch para stakeholders
- Quando quer focar em resultados

---

## 🔄 Fluxo da Demonstração

### **Estado Inicial (v1.0)**
```jsx
<h1>Welcome to the E-commerce App</h1>
```

### **Estado Final (v2.0)**
```jsx
<h1>Welcome to the E-commerce App - Versão 2.0 🚀</h1>
```

### **Timeline Típica:**
```
00:00 - Developer edita Home.js
01:00 - Build Docker image v2.0
04:00 - Push para ECR
04:30 - Update manifests Kubernetes
05:00 - Git commit + push (TRIGGER GITOPS!)
06:00 - ArgoCD detecta mudança
06:30 - ArgoCD aplica sync
07:00 - Kubernetes cria novo pod
07:30 - Novo pod ready
08:00 - Pod antigo termina
08:30 - ✅ Deploy completo (v2.0 no ar!)
```

---

## 🎯 Modificações Realizadas

### **Arquivo Principal: Home.js**

**Linha 10 modificada:**
```diff
- <h1>Welcome to the E-commerce App</h1>
+ <h1>Welcome to the E-commerce App - Versão 2.0 🚀</h1>
```

**Impacto:**
- ✅ Mudança visualmente clara para audiência
- ✅ Não quebra funcionalidade existente
- ✅ Demonstra deploy real de código
- ✅ Evidencia GitOps workflow completo

---

## 🔄 Como Reverter para v1.0 (Rollback)

### **Opção 1: Via Git**
```bash
# Restaurar arquivo original
cp microservices/ecommerce-ui/src/pages/Home.js.v1-original \
   microservices/ecommerce-ui/src/pages/Home.js

# Rebuild e push
# ... (mesmos passos da demo)
```

### **Opção 2: Via ArgoCD History**
```bash
argocd app history ecommerce-staging
argocd app rollback ecommerce-staging <REVISION-ID>
```

### **Opção 3: Via Git Revert**
```bash
git revert HEAD
git push origin main
# ArgoCD vai aplicar automaticamente
```

---

## 📊 Checklist Pré-Demo

### **Infraestrutura:**
- [ ] Cluster EKS rodando
- [ ] 3 nodes healthy
- [ ] Istio instalado e operational
- [ ] ArgoCD instalado e sincronizado
- [ ] Aplicação ecommerce rodando em staging
- [ ] LoadBalancer com URL acessível

### **Ferramentas:**
- [ ] Docker instalado e rodando
- [ ] AWS CLI configurado
- [ ] kubectl configurado
- [ ] argocd CLI instalado
- [ ] kustomize instalado
- [ ] Git configurado (user.name, user.email)

### **Código:**
- [ ] Código fonte em microservices/ecommerce-ui/src/
- [ ] Home.js com versão 2.0 pronta
- [ ] Backup Home.js.v1-original criado
- [ ] Dockerfile validado
- [ ] package.json presente

### **Apresentação:**
- [ ] Browser aberto com app URL
- [ ] Browser aberto com ArgoCD URL
- [ ] Terminais preparados
- [ ] Scripts executáveis (chmod +x)
- [ ] Documentação impressa/acessível

---

## 🚨 Troubleshooting

### **Problema: Arquivos src/ não existem**
```bash
# Extrair do container em execução
kubectl exec -n ecommerce-staging deployment/ecommerce-ui -- \
  tar czf - /app/client/src | tar xzf - -C /tmp/
  
cp -r /tmp/app/client/src/* microservices/ecommerce-ui/src/
```

### **Problema: Docker build falha**
```bash
# Verificar Dockerfile
cat microservices/ecommerce-ui/Dockerfile

# Verificar package.json
cat microservices/ecommerce-ui/package.json

# Verificar src/ existe
ls -la microservices/ecommerce-ui/src/
```

### **Problema: Git push rejeitado**
```bash
# Pull primeiro
git pull origin main --rebase

# Resolve conflitos se houver
git push origin main
```

### **Problema: ArgoCD não sync**
```bash
# Force refresh
argocd app get ecommerce-staging --refresh

# Force sync
argocd app sync ecommerce-staging --force

# Ver logs
kubectl logs -n argocd deployment/argocd-application-controller
```

---

## 🎯 Arquivos Modificados pela Demo

### **Ao executar demo, os seguintes arquivos são modificados:**

1. **microservices/ecommerce-ui/src/pages/Home.js**
   - Linha 10: Adiciona "Versão 2.0 🚀"

2. **k8s-manifests/staging/kustomization.yaml**
   - Seção images: Atualiza tag para v2.0

3. **Git commit criado:**
   ```
   feat: Update UI to version 2.0
   
   - Changed welcome message to include 'Versão 2.0 🚀'
   - Updated Docker image tag to v2.0
   - Developer: Team Frontend
   ```

---

## 📈 Métricas de Sucesso

### **O que medir durante a demo:**

✅ **Tempo de Deploy:**
- Commit → Deploy: < 5 minutos ⭐

✅ **Zero Downtime:**
- Aplicação continuou respondendo durante todo deploy

✅ **Auditoria:**
- Commit no Git com mensagem clara
- ArgoCD mostra exatamente qual revision está deployed

✅ **Rollback:**
- Demonstrar que rollback leva < 30 segundos

✅ **Observabilidade:**
- Kiali mostra tráfego em tempo real
- Grafana mostra métricas dos pods

---

## 🎓 Conceitos Demonstrados

### **1. GitOps Principles**
- ✅ **Declarativo:** Estado desejado no Git
- ✅ **Versioned:** Tudo no controle de versão
- ✅ **Automatically Applied:** ArgoCD aplica mudanças
- ✅ **Continuously Reconciled:** Cluster sempre sincronizado

### **2. CI/CD Pipeline**
- ✅ Build de imagens Docker
- ✅ Push para registry (ECR)
- ✅ Update de manifests
- ✅ Deploy automatizado

### **3. Kubernetes Patterns**
- ✅ Rolling updates (zero downtime)
- ✅ Readiness probes (health checks)
- ✅ Kustomize (gestão de configs)
- ✅ Multi-environment (staging/production)

### **4. Service Mesh (Istio)**
- ✅ Traffic management
- ✅ Observability
- ✅ Security (mTLS)
- ✅ Load balancing

---

## 📖 Documentação Adicional

- **Guia GitOps:** [GITOPS-GUIDE.md](../GITOPS-GUIDE.md)
- **Quick Start:** [QUICK-START.md](../QUICK-START.md)
- **Troubleshooting:** [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
- **Repositório:** https://github.com/jlui70/istio-eks-terraform-gitops

---

## 🤝 Suporte

Em caso de problemas:

1. Verificar logs: `kubectl logs`
2. Verificar events: `kubectl get events`
3. Consultar documentação acima
4. Abrir issue no GitHub

---

## ✨ Próximos Passos Após Demo

1. **Feedback:** Coletar feedback da audiência
2. **Production:** Deploy para production (manual sync)
3. **CI/CD:** Integrar com GitHub Actions
4. **Monitoring:** Configurar alertas
5. **Cleanup:** `./scripts/destroy-gitops-stack.sh`

---

**Criado para demonstração GitOps - Dezembro 2024**

**Boa apresentação! 🚀**
