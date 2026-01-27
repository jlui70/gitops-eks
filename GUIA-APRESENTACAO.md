# 🎯 GUIA DE APRESENTAÇÃO - CI/CD GitOps

## ✅ CHECKLIST PRÉ-APRESENTAÇÃO

### 1. Verificar Infraestrutura
```bash
# Verificar cluster EKS
kubectl get nodes

# Verificar pods rodando (v1)
kubectl get pods -n ecommerce

# Verificar URL da aplicação
kubectl get ingress ecommerce-ingress -n ecommerce
```

### 2. Abrir Tabs do Browser
- ✅ GitHub Actions: https://github.com/jlui70/gitops-eks-test/actions
- ✅ Docker Hub: https://hub.docker.com/u/luiz7030
- ✅ AWS ECR Console: https://console.aws.amazon.com/ecr/repositories?region=us-east-1
- ✅ Aplicação v1 (URL do ALB)

### 3. Terminal Preparado
```bash
cd /home/luiz7/Projects/testes/gitops-eks
```

---

## 🎬 ROTEIRO DA APRESENTAÇÃO

### PARTE 1: INTRODUÇÃO (2 min)

**Explicar o Projeto:**
- Pipeline GitOps completo para Kubernetes (EKS)
- CI/CD automatizado com GitHub Actions
- Blue/Green Deployment para zero downtime
- Docker Hub → ECR → EKS

**Mostrar Infraestrutura:**
```bash
# Mostrar cluster
kubectl get nodes -o wide

# Mostrar aplicação v1 rodando
kubectl get deployments -n ecommerce
kubectl get pods -n ecommerce

# Abrir aplicação v1 no navegador
echo "Aplicação v1 disponível em: http://$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

---

### PARTE 2: DEMONSTRAÇÃO CI - BUILD AUTOMÁTICO (5 min)

**Explicar o Fluxo CI:**
> "Quando um desenvolvedor faz push de código, o CI é disparado automaticamente.
> O pipeline valida, faz build das imagens Docker, e envia para o registry."

**Trigger do CI:**
```bash
# Fazer uma alteração simples
echo "# Demo CI/CD - Apresentação $(date)" >> 06-ecommerce-app/README.md

# Commit e push
git add 06-ecommerce-app/README.md
git commit -m "feat: demo CI pipeline para apresentação"
git push test main
```

**Mostrar no GitHub Actions:**
1. Ir para: https://github.com/jlui70/gitops-eks-test/actions
2. Clicar no workflow "CI - Build and Test" em execução
3. Mostrar os jobs:
   - ✅ **Validate**: Validação dos manifestos Kubernetes
   - 🔄 **Build**: Pull do Docker Hub → Build → Push para ECR (7 microserviços)
   - ✅ **Test**: Testes automatizados

**Enquanto CI roda, mostrar Docker Hub:**
- Abrir: https://hub.docker.com/u/luiz7030
- Mostrar as 7 imagens disponíveis
- Explicar: "Estas são as imagens base. O CI faz pull daqui e envia para o ECR privado da AWS"

**Aguardar CI completar (~2-3 min)**

---

### PARTE 3: DEMONSTRAÇÃO CD - DEPLOY BLUE/GREEN (5 min)

**Explicar a Estratégia Blue/Green:**
> "Vamos fazer deploy da versão 2 sem derrubar a v1.
> Ambas versões rodam em paralelo (Blue/Green).
> Depois fazemos o switch de tráfego sem downtime."

**Estado Atual:**
```bash
# Verificar que só tem v1 rodando
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version
```

**Executar CD Manual no GitHub:**
1. GitHub Actions → **"CD - Deploy to EKS"**
2. Clicar **"Run workflow"**
3. Configurar:
   - Environment: `production`
   - Version: `latest`
   - Deployment strategy: `blue-green`
4. Clicar **"Run workflow"** (botão verde)

**Mostrar o CD Rodando:**
- Abrir o workflow em execução
- Mostrar steps:
  - ✅ Deploy v2 (pods novos criados)
  - ✅ Health Check (aguarda pods prontos)
  - ✅ Switch Traffic (v1 → v2)
  - ✅ Verify Deployment

**Tempo: ~40 segundos**

---

### PARTE 4: VALIDAÇÃO DA ATUALIZAÇÃO (3 min)

**Verificar Pods (Blue/Green ativo):**
```bash
# Agora deve ter v1 E v2 rodando
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version

# Ver que o service aponta para v2
kubectl get service ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' && echo
```

**Mostrar Aplicação Atualizada:**
```bash
# Pegar URL
kubectl get ingress ecommerce-ingress -n ecommerce
```

- Abrir no navegador
- Mostrar que está rodando **v2**
- Comparar visualmente com v1 (se houver diferenças visuais)

**Explicar:**
> "A aplicação foi atualizada sem nenhum downtime.
> Durante o deploy, a v1 continuou recebendo tráfego.
> Só fizemos o switch quando a v2 estava 100% pronta."

---

### PARTE 5 (OPCIONAL): ROLLBACK RÁPIDO (2 min)

**Explicar Rollback:**
> "Se algo der errado na v2, podemos voltar para v1 em segundos.
> Isso é uma vantagem do Blue/Green - rollback instantâneo."

**Opção A - Via GitHub Actions:**
1. Actions → **"Rollback Deployment"** → Run workflow

**Opção B - Via Comando (MAIS RÁPIDO):**
```bash
# Voltar service para v1
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'

# Verificar
kubectl get service ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' && echo
```

**Tempo: < 10 segundos**

**Atualizar browser e mostrar que voltou para v1**

---

## 📊 PONTOS-CHAVE PARA DESTACAR

### Benefícios do GitOps:
- ✅ **Automação completa**: Commit → Build → Deploy
- ✅ **Rastreabilidade**: Todo deploy tem commit associado
- ✅ **Segurança**: Secrets gerenciados, RBAC configurado
- ✅ **Reprodutibilidade**: Infraestrutura como código

### Benefícios do Blue/Green:
- ✅ **Zero downtime**: Aplicação sempre disponível
- ✅ **Rollback instantâneo**: < 30 segundos
- ✅ **Testes em produção**: v2 roda antes de receber tráfego
- ✅ **Segurança**: Validação completa antes do switch

### Tecnologias Utilizadas:
- 🐳 **Docker**: Containerização
- ☸️ **Kubernetes (EKS)**: Orquestração
- 🔄 **GitHub Actions**: CI/CD
- 🏗️ **Terraform**: Infraestrutura como Código
- ☁️ **AWS**: Cloud Provider (ECR, EKS, ALB, Route53)

---

## 🚨 TROUBLESHOOTING

### Se CI falhar:
```bash
# Verificar logs do GitHub Actions
# Verificar se images estão no Docker Hub: hub.docker.com/u/luiz7030
# Verificar credenciais AWS nos secrets
```

### Se CD falhar:
```bash
# Verificar pods
kubectl get pods -n ecommerce

# Ver logs
kubectl logs -n ecommerce -l version=v2 --tail=50

# Diagnóstico completo
cd 06-ecommerce-app
./diagnose-503.sh
```

### Se aplicação não responder:
```bash
# Verificar ingress
kubectl describe ingress ecommerce-ingress -n ecommerce

# Verificar service endpoints
kubectl get endpoints ecommerce-ui -n ecommerce

# Port-forward para teste direto
kubectl port-forward -n ecommerce svc/ecommerce-ui 8080:80
# Abrir: http://localhost:8080
```

---

## 📋 COMANDOS RÁPIDOS DE REFERÊNCIA

```bash
# Ver todos os recursos do ecommerce
kubectl get all -n ecommerce

# Ver pods com labels de versão
kubectl get pods -n ecommerce -L version

# Ver service selector
kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 2 selector

# Logs em tempo real da v2
kubectl logs -n ecommerce -l version=v2 -f

# Deletar deployment v2 (cleanup)
kubectl delete deployment ecommerce-ui-v2 ecommerce-ui-backend -n ecommerce

# Restart deployments
kubectl rollout restart deployment -n ecommerce
```

---

## ⏱️ TIMING SUGERIDO

| Etapa | Tempo | Total |
|-------|-------|-------|
| Introdução + Infraestrutura | 2 min | 2 min |
| Trigger CI + Explicação | 1 min | 3 min |
| Aguardar CI completar | 2 min | 5 min |
| Trigger CD + Explicação | 1 min | 6 min |
| Aguardar CD completar | 1 min | 7 min |
| Validação da v2 | 2 min | 9 min |
| Rollback (opcional) | 2 min | 11 min |
| Perguntas e conclusão | 4 min | **15 min** |

---

## 🎯 MENSAGEM FINAL

> "Este projeto demonstra uma pipeline GitOps production-ready que pode ser
> utilizada em ambientes empresariais reais. Combina automação, segurança,
> e práticas modernas de DevOps para entregas rápidas e confiáveis."

**Tecnologias mostradas:**
- CI/CD com GitHub Actions
- Kubernetes (Amazon EKS)
- Blue/Green Deployment
- Docker & Container Registry
- Infraestrutura como Código
- GitOps Workflow

---

## 📞 LINKS IMPORTANTES

- **Repo Principal**: https://github.com/jlui70/gitops-eks
- **Repo de Teste**: https://github.com/jlui70/gitops-eks-test
- **Docker Hub**: https://hub.docker.com/u/luiz7030
- **Portfólio**: https://devopsproject.com.br

---

**Última atualização:** 27/01/2026
**Preparado por:** GitHub Copilot Assistant
