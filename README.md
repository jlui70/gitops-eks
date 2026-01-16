# Projeto EKS-TERRAFORM-ANSIBLE - Infraestrutura AWS Production Grade

<p align="center">
  <img src="https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Automation-Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white" />
  <img src="https://img.shields.io/badge/Kubernetes-K8s-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>

> Infraestrutura completa para provisionar um **Cluster Amazon EKS production-grade** utilizando **Terraform** e **Ansible** com stacks modulares para gerenciamento de recursos AWS.

Este projeto apresenta uma proposta de implantação completa com Terraform + Ansible, a base do DevOps moderno. Dominar essas tecnologias podem elevar o seu nível profissional.

Este projeto inclui:
- ✅ **EKS Cluster 1.32** com Node Groups gerenciados
- ✅ **AWS Load Balancer Controller** para Ingress
- ✅ **External DNS** para gerenciamento automático de DNS
- ✅ **3 stacks Terraform** modulares e reutilizáveis
- ✅ **Aplicação E-commerce** com 7 microserviços
- ✅ **Ansible** para validação e deploy automatizado
- ✅ **Scripts de automação** para deploy e destroy

---

## 🚀 Fluxo de Deployment Simplificado

```
┌──────────────────────────────────────────────────────────────┐
│ FASE 1: Terraform (30-40 min)                               │
├──────────────────────────────────────────────────────────────┤
│ 1. Stack 00 (Backend)     → S3 + DynamoDB                   │
│ 2. Stack 01 (Networking)  → VPC + Subnets + NAT             │
│ 3. Stack 02 (EKS Cluster) → EKS + ALB + ExternalDNS         │
└──────────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ FASE 2: Ansible (5 min)                                     │
├──────────────────────────────────────────────────────────────┤
│ 1. Validar Cluster (playbook 02)                            │
│    ansible-playbook playbooks/02-validate-cluster.yml       │
│                                                              │
│ 2. Deploy E-commerce (playbook 03)                          │
│    ansible-playbook playbooks/03-deploy-ecommerce.yml       │
└──────────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ RESULTADO: App funcionando em eks.devopsproject.com.br      │
└──────────────────────────────────────────────────────────────┘
```

---

## 📋 Pré-requisitos (Obrigatório)

Antes de iniciar o deployment, certifique-se de ter:

- **AWS Account** com permissões administrativas
- **AWS CLI** configurado (versão 2.x recomendada)
- **Terraform** instalado (versão 1.12.x ou superior)
- **kubectl** instalado (versão compatível com EKS 1.32)
- **Helm** instalado (versão 3.x)
- **Conta AWS Paid Plan** ou créditos suficientes (Free Tier não suporta instâncias t3.medium)

> ⚠️ **IMPORTANTE:** O projeto utiliza instâncias **t3.medium** para os worker nodes. Contas AWS Free Tier são limitadas a t3.micro/t3.small. Certifique-se de ter upgrade para Paid Plan ou créditos AWS disponíveis.
>
> 💰 **ESTIMATIVA DE CUSTO PARA LABORATÓRIO:**
> - **30 minutos de teste:** ~$0.30 USD
> - **2 horas completas (deploy + validação):** ~$1.20 USD
> - **8 horas (dia de estudo):** ~$4.80 USD
> 
> **💡 DICA:** Execute `terraform destroy` imediatamente após os testes para evitar cobranças contínuas. O custo de ~$120/mês mencionado abaixo é apenas se você mantiver a infraestrutura rodando 24/7.

### **📚 Siga as orientações no Documento de Configuração Inicial abaixo:**

**[CONFIGURAÇÃO-INICIAL.md](./docs/Configuração-inicial.md)** 

---
## Deploy ⚠️ **IMPORTANTE:**

## (Iniciei o Deploy apenas quando finalizar a Configuração Inicial)

## 🚀 Sequência de Deploy 

### Stack 00 - Backend (S3 + DynamoDB)

A stack `backend` cria o bucket S3 e a tabela DynamoDB para o Terraform state locking e remote backend:

```bash
cd ./00-backend
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 3 (S3 bucket, S3 versioning, DynamoDB table)

📌 **Observação:** O comando considera que você está na pasta root do projeto.

---

### Stack 01 - Networking (VPC, Subnets, NAT)

Crie a base de redes para as próximas stacks:

```bash
cd ../01-networking
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 21 (VPC, Internet Gateway, 6 Subnets, NAT Gateways, Route Tables, EIPs)

**⏱️ Tempo estimado:** 2-3 minutos

---

### Stack 02 - EKS Cluster

Crie um Cluster EKS com addons instalados.

**ANTES DE APLICAR:**

1. ✅ Substitua `<YOUR_ACCOUNT>` em todos os arquivos `.tf` (veja seção 5.1)
2. ✅ EKS Access já está configurado automaticamente com terraform-role (veja seção 5.2)

```bash
cd ../02-eks-cluster
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 21 (EKS Cluster, Node Group, IAM Roles, Addons, OIDC Provider, ALB Controller, External DNS)

**⏱️ Tempo estimado:** 15-20 minutos (inclui provisionamento dos node groups)

---

### Configurar kubectl (OBRIGATÓRIO)

Após o deploy do Stack 02, configure o kubectl para acessar o cluster:

```bash
aws eks update-kubeconfig \
    --name <CLUSTER_NAME> \
    --region us-east-1 \
    --profile terraform
```

> 📝 **Nota:** Substitua `<CLUSTER_NAME>` pelo nome do seu cluster. Se você não alterou as variáveis do Terraform, o nome padrão é `eks-devopsproject-cluster`.

**Exemplo:**
```bash
aws eks update-kubeconfig \
    --name eks-devopsproject-cluster \
    --region us-east-1 \
    --profile terraform
```

Teste o acesso:

```bash
kubectl get nodes
kubectl get pods -A
```

**✅ Validação esperada:**
- 3 nodes no estado `Ready`
- Pods do kube-system rodando
- Pods do aws-load-balancer-controller (2/2 Ready)
- Pods do external-dns (1/1 Ready)

---

### Configuração Aplicação E-commerce

Após deploy das 3 stacks, você pode fazer deploy da aplicação e-commerce usando Ansible ou manualmente.

#### Opção 1: Deploy Automatizado com Ansible (Recomendado)

```bash
cd ansible

# 1. Validar cluster
ansible-playbook playbooks/02-validate-cluster.yml

# 2. Deploy aplicação e-commerce
ansible-playbook playbooks/03-deploy-ecommerce.yml
```

**⏱️ Tempo estimado:** 3-5 minutos

#### Opção 2: Deploy Manual

```bash
cd 06-ecommerce-app
./deploy.sh
```

**⏱️ Tempo estimado:** 10-15 minutos
3. Vá em **Users** → **Add user**:
   - Username: `grafana-admin` (ou seu email)
   - Email: seu-email@exemplo.com
   - First/Last name: Seu nome
4. Você receberá email para ativar conta
5. Após ativar, vá em **AWS accounts** → Selecione sua conta
6. Clique em **Assign users** → Selecione `grafana-admin`
7. Na tela de Permission sets, **pule** (não precisa permission set para Grafana)

> 📝 **Nota:** Este é o **ÚNICO processo manual obrigatório** do projeto. Todo o resto é automatizado via Terraform + Ansible.

```bash
cd ../05-monitoring
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 7 (Prometheus Workspace, Prometheus Scraper, Grafana Workspace, IAM Roles, CloudWatch Log Group, EKS Addon Node Exporter)

**⏱️ Tempo estimado:** 20-25 minutos (Prometheus Scraper ~17min, Grafana Workspace ~6min)

**✅ Validação:**

```bash
# Ver outputs
terraform output

# Verificar Prometheus Scraper
aws amp list-scrapers --profile terraform --region us-east-1

# Verificar pods do Node Exporter
kubectl get pods -n prometheus-node-exporter
# Esperado: 3 pods Running (1 por nó)
```

---

### Configuração Aplicação E-commerce

Após deploy das 3 stacks, você pode fazer deploy da aplicação e-commerce usando Ansible ou manualmente.

#### Opção 1: Deploy Automatizado com Ansible (Recomendado)

```bash
cd ansible

# 1. Validar cluster
ansible-playbook playbooks/02-validate-cluster.yml

# 2. Deploy aplicação e-commerce
ansible-playbook playbooks/03-deploy-ecommerce.yml
```

**⏱️ Tempo estimado:** 3-5 minutos

**O que o playbook faz automaticamente:**

1. ✅ **Valida pré-requisitos** (kubectl, cluster, ALB Controller)
2. ✅ **Cria namespace** `ecommerce`
3. ✅ **Deploya 7 microserviços:**
   - `ecommerce-ui` (frontend React - porta 4000)
   - `product-catalog` (catálogo de produtos - porta 5001)
   - `order-management` (gestão de pedidos - porta 5002)
   - `product-inventory` (estoque - porta 5003)
   - `profile-management` (perfis de usuários - porta 5004)
   - `shipping-and-handling` (envios - porta 5005)
   - `team-contact-support` (suporte - porta 5006)
4. ✅ **Aguarda pods ficarem prontos** (até 300s)
5. ✅ **Deploya Ingress** (provisiona ALB)
6. ✅ **Aguarda ALB ser criado** (~2-3 min)
7. ✅ **Valida health check**
8. ✅ **Salva informações** em `ansible/ecommerce-info.txt`

#### Opção 2: Deploy Manual

```bash
cd 06-ecommerce-app
./deploy.sh
```

**⏱️ Tempo estimado:** 10-15 minutos

#### Configurar DNS Personalizado (CNAME) (Opcional)

O acesso à aplicação E-commerce já está disponível via ALB. Se desejar acesso via DNS personalizado:

1. Obter o ALB URL:
   ```bash
   kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
2. Crie registro CNAME no seu provedor DNS:
   ```
   Tipo: CNAME
   Nome: eks (ou o que preferir)
   Destino: [ALB-URL]
   TTL: 300
   ```
3. Aguarde propagação: 5-10 minutos

**Validar DNS:**

```bash
# Verificar resolução
dig eks.seudominio.com.br

# Testar acesso
curl -I http://eks.seudominio.com.br
# Esperado: HTTP/1.1 200 OK
```

---

## ✅ Validação Completa da Infraestrutura

Após completar as 3 stacks, valide tudo:

**1. Cluster e Nós:**
```bash
kubectl get nodes
# Esperado: 3 nodes Ready
```

**2. Pods da Aplicação:**
```bash
kubectl get pods -n ecommerce
# Esperado: 7 pods Running (ecommerce-ui, product-catalog, order-management, etc.)
```

**3. Ingress e ALB:**
```bash
kubectl get ingress -n ecommerce
# Esperado: ADDRESS preenchido com ALB URL
```

**4. Acessar Aplicação:**
```bash
# Via ALB direto
curl -I http://[ALB-URL]

# Via DNS personalizado (se configurado)
curl -I http://eks.devopsproject.com.br
# Esperado: HTTP/1.1 200 OK
```

---

### 📊 Resumo de Recursos Provisionados

| Stack | Recursos | Tempo | Automação | Status |
|-------|----------|-------|-----------|--------|
| 00 - Backend | 3 | < 1 min | Terraform | Obrigatório |
| 01 - Networking | 21 | 2-3 min | Terraform | Obrigatório |
| 02 - EKS Cluster | 21 | 15-20 min | Terraform | Obrigatório |
| 06 - E-commerce App | 9 (K8s) | **3-5 min** | **Ansible** | Opcional |
| **TOTAL** | **54** | **~20-25 min** | **Terraform + Ansible** | **Infraestrutura Funcional** |

**Processos Manuais (Opcional):**
- ✋ Configuração DNS CNAME (~2 min, se quiser DNS personalizado)

**Tudo mais é automatizado:** Terraform + Ansible

---

## 🤖 Scripts de Automação

Este projeto inclui scripts para **deploy** e **destroy** completos da infraestrutura.

### 🚀 rebuild-all.sh - Deploy Automatizado

Recria toda a infraestrutura do zero automaticamente (Stacks 00 → 02).

```bash
scripts/rebuild-all.sh
```

**O que o script faz:**
1. ✅ Aplica as 3 stacks na ordem correta
2. ✅ Aguarda S3 backend estar disponível (10s)
3. ✅ Configura kubectl automaticamente
4. ✅ Opcionalmente cria deployment NGINX de teste

**⏱️ Tempo total:** ~20-25 minutos

**📋 Recursos criados:** 45 recursos Terraform

---

### 🗑️ destroy-all.sh - Destruição Completa ⚠️ IMPORTANTE

**Destrói TODOS os recursos** na ordem reversa para **eliminar custos AWS**.

```bash
scripts/destroy-all.sh
```

**⚠️ EXECUTE ESTE SCRIPT APÓS TERMINAR OS TESTES PARA EVITAR CUSTOS DIÁRIOS!**

**O que o script faz automaticamente:**

1. ✅ **Deleta recursos Kubernetes** (namespaces, Ingress → ALB)
   - Namespace `ecommerce` (7 microserviços)
   - Namespace `sample-app` (se existir)
   - Helm releases órfãos
   
2. ✅ **Aguarda ALB ser deletado** (45s)

3. ✅ **Destrói Stack 02** (EKS Cluster)
   - Remove recursos órfãos do Terraform state automaticamente
   - Limpa helm releases órfãos

4. ✅ **Limpa IAM Roles/Policies órfãs**
   - Lê nomes reais do Terraform state
   - Previne erro "EntityAlreadyExists" em reinstalações
   - Deleta instance profiles órfãos

5. ✅ **Destrói Stack 01** (VPC + Subnets + NAT Gateways)

6. ❓ **Pergunta sobre Stack 00** (Backend S3 + DynamoDB)
   - Se destruir: remove state remoto completamente
   - Se preservar: mantém histórico do Terraform

**⏱️ Tempo total:** ~10-15 minutos

**💰 Custo AWS após destroy:** **$0/mês** (se destruir backend também)

---

### ⚠️ AVISOS IMPORTANTES SOBRE CUSTOS

| Cenário | Custo/mês | Ação Recomendada |
|---------|-----------|------------------|
| **Cluster rodando 24/7** | **~$120/mês** | ⚠️ **Destruir após testes!** |
| **Cluster por 8 horas** | ~$4 | ✅ OK para estudo |
| **Cluster por 2 horas** | ~$1 | ✅ OK para demonstração |
| **Após destroy completo** | **$0/mês** | ✅ **EXECUTE destroy-all.sh!** |

**🎯 LEMBRE-SE:** AWS cobra por hora. Se você esquecer o cluster rodando, **acumulará custos diários**.

**Principais recursos que geram custo:**
- 💰 **3x instâncias EC2 t3.medium** (~$50/mês)
- 💰 **2x NAT Gateways** (~$64/mês) - o mais caro!
- 💰 **EKS Cluster** (~$73/mês)
- 💰 **ALB** (~$18/mês)
- 💰 **Transferência de dados** (variável)

---

### 🔄 Fluxo Completo: Deploy → Testes → Destroy

```bash
# 1. Deploy completo (20-25 min)
scripts/rebuild-all.sh

# 2. Validar cluster (1 min)
cd ansible
ansible-playbook playbooks/02-validate-cluster.yml

# 3. Deploy E-commerce App (3-5 min)
ansible-playbook playbooks/03-deploy-ecommerce.yml
cd ..

# 4. Testar tudo (30 min - 2 horas)
kubectl get nodes
kubectl get pods -n ecommerce
kubectl get ingress -n ecommerce

# Acessar aplicação via ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL

# 5. DESTRUIR TUDO (10-15 min) ⚠️ CRÍTICO!
scripts/destroy-all.sh
# Responda "s" quando perguntar sobre backend

# 6. Validar custos zerados
aws eks list-clusters --profile terraform
# Esperado: []

aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --profile terraform
# Esperado: nenhuma instância
```

**Custo total do teste:** ~$1 (se destruir após 2 horas)

---

## 🙏 Créditos

Este projeto é baseado no trabalho original de **[Kenerry Serain](https://github.com/kenerry-serain)**, desenvolvido como material do curso **DevOps na Nuvem**.

Agradecimentos especiais pela estrutura e conhecimento compartilhado que tornou este projeto possível.

**Repositório Original:** [kenerry-serain (GitHub)](https://github.com/kenerry-serain)

---

## 📜 Licença

Este projeto está sob licença MIT.

---

## 📞 Contato e Suporte

### 🌐 Conecte-se Comigo

- 📹 **YouTube:** [DevOps Project](https://www.youtube.com/@devops-project)
- 💼 **Portfólio:** [devopsproject.com.br](https://devopsproject.com.br/)
- 💻 **GitHub:** [@jlui70](https://github.com/jlui70)

### 🌟 Gostou do Projeto?

Se este projeto foi útil para você:

- ⭐ Dê uma **estrela** no repositório
- 🔄 **Compartilhe** com a comunidade
- 📹 **Inscreva-se** no canal do YouTube
- 🤝 **Contribua** com melhorias

<div align="center">

**🚀 Enterprise-grade infrastructure com Terraform e Ansible**

[![Ansible](https://img.shields.io/badge/Automation-Ansible-EE0000?style=for-the-badge&logo=ansible)](https://www.ansible.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)

</div>

---

<p align="center">
  <strong>Desenvolvido com ❤️ para a comunidade brasileira de DevOps, SRE e Cloud Engineering</strong>
</p>

