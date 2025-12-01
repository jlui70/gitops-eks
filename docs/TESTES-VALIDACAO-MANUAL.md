# Testes e Validação Manual da Infraestrutura

Este documento descreve testes **manuais** que você pode executar para validar os componentes da infraestrutura EKS.

> 💡 **RECOMENDAÇÃO:** Para ambientes de produção/staging, considere automatizar estes testes com **Ansible** ou **CI/CD pipelines**.
>
> 📚 Ver: [QUICK-START-ANSIBLE.md](./QUICK-START-ANSIBLE.md)

---

## Quando Usar Este Guia

Use estes testes manuais para:
- ✅ Validar deployment inicial da infraestrutura
- ✅ Troubleshooting de problemas específicos
- ✅ Aprender como cada componente funciona
- ✅ Demonstração didática em aulas/workshops

**Para automação de testes,** considere criar playbooks Ansible baseados nestes procedimentos.

---

## 📋 Pré-requisitos

Antes de executar os testes, certifique-se que:

✅ **Todas as stacks Terraform foram aplicadas:**
- Stack 00 (Backend)
- Stack 01 (Networking)
- Stack 02 (EKS Cluster)
- Stack 03 (Karpenter)
- Stack 04 (Security/WAF)
- Stack 05 (Monitoring)

✅ **kubectl está configurado:**
```bash
aws eks update-kubeconfig \
    --name eks-devopsproject-cluster \
    --region us-east-1 \
    --profile terraform
```

✅ **AWS CLI está configurado com profile terraform:**
```bash
aws sts get-caller-identity --profile terraform
```

---

## 🧪 Teste 1: Validar Componentes Básicos do EKS

### 1.1. Verificar Nodes do Cluster

```bash
kubectl get nodes
```

**✅ Resultado esperado:**
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-0-123.ec2.internal   Ready    <none>   5h    v1.32.0-eks-xxxxx
ip-10-0-0-124.ec2.internal   Ready    <none>   5h    v1.32.0-eks-xxxxx
ip-10-0-0-125.ec2.internal   Ready    <none>   5h    v1.32.0-eks-xxxxx
```

- ✅ 3 nodes no estado `Ready`
- ✅ Versão do Kubernetes: 1.32.x

---

### 1.2. Verificar Pods de Sistema

```bash
kubectl get pods -A
```

**✅ Resultado esperado:**
- Todos os pods em estado `Running` ou `Completed`
- Namespaces esperados:
  - `kube-system`: core DNS, kube-proxy, vpc-cni
  - `aws-load-balancer-controller`: 2 pods Running
  - `external-dns`: 1 pod Running
  - `kube-system` (karpenter): 2 pods Running
  - `prometheus-node-exporter`: 3 pods Running (1 por node)

---

### 1.3. Verificar Addons EKS

```bash
aws eks list-addons \
    --cluster-name eks-devopsproject-cluster \
    --profile terraform
```

**✅ Resultado esperado:**
```json
{
    "addons": [
        "aws-ebs-csi-driver",
        "coredns",
        "eks-pod-identity-agent",
        "kube-proxy",
        "prometheus-node-exporter",
        "vpc-cni"
    ]
}
```

---

## 🧪 Teste 2: Validar EBS CSI Driver (Persistent Volumes)

### 2.1. Criar Deployment de Teste com PVC

**Arquivo:** `02-eks-cluster/samples/csi-sample-deployment.yml`

```bash
kubectl apply -f 02-eks-cluster/samples/csi-sample-deployment.yml
```

---

### 2.2. Verificar PVC e PV

```bash
# Verificar PersistentVolumeClaim
kubectl get pvc -n csi-test

# Verificar PersistentVolume
kubectl get pv
```

**✅ Resultado esperado:**
- PVC `ebs-claim` no estado `Bound`
- PV criado automaticamente com `STATUS: Bound`

---

### 2.3. Verificar Pod e Volume EBS

```bash
# Verificar pod
kubectl get pods -n csi-test

# Verificar volume montado dentro do pod
kubectl exec -n csi-test -it $(kubectl get pod -n csi-test -o name) -- df -h /data
```

**✅ Resultado esperado:**
- Pod `app` em estado `Running`
- Montagem do volume visível em `/data`

---

### 2.4. Validar Persistência de Dados

```bash
# Escrever dados no volume
kubectl exec -n csi-test -it $(kubectl get pod -n csi-test -o name) -- sh -c "echo 'Teste de persistência' > /data/test.txt"

# Deletar o pod (será recriado pelo Deployment)
kubectl delete pod -n csi-test -l app=csi-test-app

# Aguardar novo pod (10-20 segundos)
kubectl wait --for=condition=ready pod -n csi-test -l app=csi-test-app --timeout=60s

# Verificar se os dados persistiram
kubectl exec -n csi-test -it $(kubectl get pod -n csi-test -o name) -- cat /data/test.txt
```

**✅ Resultado esperado:**
```
Teste de persistência
```

---

### 2.5. Cleanup

```bash
kubectl delete -f 02-eks-cluster/samples/csi-sample-deployment.yml
```

---

## 🧪 Teste 3: Validar ALB Ingress Controller + WAF

### 3.1. Criar Deployment com Ingress

**Arquivo:** `02-eks-cluster/samples/ingress-sample-deployment.yml`

```bash
kubectl apply -f 02-eks-cluster/samples/ingress-sample-deployment.yml
```

---

### 3.2. Aguardar Provisionamento do ALB

```bash
kubectl get ingress eks-devopsproject-ingress -n sample-app -w
```

**✅ Resultado esperado:**
- Após ~2-3 minutos, coluna `ADDRESS` mostrará o DNS do ALB
- Formato: `k8s-sampleap-xxxxxxxx-xxxxxxxxxx.us-east-1.elb.amazonaws.com`

Pressione `Ctrl+C` quando o ADDRESS aparecer.

---

### 3.3. Testar Acesso HTTP ao ALB

```bash
# Obter URL do ALB
ALB_URL=$(kubectl get ingress eks-devopsproject-ingress -n sample-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Aguardar DNS propagar (60-90 segundos)
echo "Aguardando DNS propagar... (60s)"
sleep 60

# Testar conexão
curl -I http://$ALB_URL
```

**✅ Resultado esperado:**
```
HTTP/1.1 200 OK
Server: nginx/1.xx.x
...
```

---

### 3.4. Testar Conteúdo da Aplicação

```bash
curl http://$ALB_URL
```

**✅ Resultado esperado:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

---

### 3.5. Verificar Associação WAF

```bash
# Obter ARN do ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-sampleap')].LoadBalancerArn" \
  --output text \
  --profile terraform)

# Verificar associação WAF
aws wafv2 get-web-acl-for-resource \
  --resource-arn "$ALB_ARN" \
  --region us-east-1 \
  --profile terraform \
  --query 'WebACL.Name' \
  --output text
```

**✅ Resultado esperado:**
```
waf-eks-devopsproject-webacl
```

---

### 3.6. Testar Regra WAF (Rate Limiting)

O WAF está configurado com rate limiting de 100 requisições por 5 minutos.

**Teste de Rate Limiting (opcional):**

```bash
# Enviar múltiplas requisições rápidas
for i in {1..120}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://$ALB_URL
  sleep 0.1
done
```

**✅ Resultado esperado:**
- Primeiras ~100 requisições: `200`
- Requisições seguintes: `403` (bloqueadas pelo WAF)

---

### 3.7. Cleanup

```bash
kubectl delete -f 02-eks-cluster/samples/ingress-sample-deployment.yml
```

**Aguarde ~2-3 minutos** para o ALB ser deletado automaticamente.

---

## 🧪 Teste 4: Validar Karpenter Auto-Scaling

### 4.1. Criar Deployment de Teste com Alta Demanda

**Arquivo:** `03-karpenter-auto-scaling/samples/karpenter-nginx-deployment.yml`

```bash
kubectl apply -f 03-karpenter-auto-scaling/samples/karpenter-nginx-deployment.yml
```

---

### 4.2. Verificar Pods Pendentes

```bash
kubectl get pods -n karpenter-test
```

**✅ Resultado esperado:**
- Alguns pods em estado `Pending` (aguardando capacity)
- Alguns pods em estado `ContainerCreating`

---

### 4.3. Verificar Logs do Karpenter

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50 -f
```

**✅ Resultado esperado:**
- Logs mostrando: `created node` ou `launching machine`
- Exemplo:
  ```
  {"level":"INFO","time":"...","message":"created node","node":"ip-10-0-1-123.ec2.internal"}
  ```

Pressione `Ctrl+C` para sair.

---

### 4.4. Verificar Novos Nodes Provisionados

```bash
kubectl get nodes -w
```

**✅ Resultado esperado:**
- Após ~90-120 segundos, novos nodes aparecem com status `Ready`
- Total de nodes aumenta (ex: de 3 para 5)

Pressione `Ctrl+C` quando os novos nodes estiverem `Ready`.

---

### 4.5. Verificar Todos os Pods Running

```bash
kubectl get pods -n karpenter-test
```

**✅ Resultado esperado:**
- Todos os pods em estado `Running` (nenhum `Pending`)

---

### 4.6. Testar Scale Down (Consolidation)

```bash
# Reduzir réplicas
kubectl scale deployment inflate -n karpenter-test --replicas=1

# Verificar nodes após ~30 segundos
kubectl get nodes -w
```

**✅ Resultado esperado:**
- Após ~30-60 segundos, Karpenter remove nodes extras
- Total de nodes retorna ao original (3 nodes)

---

### 4.7. Cleanup

```bash
kubectl delete -f 03-karpenter-auto-scaling/samples/karpenter-nginx-deployment.yml
```

---

## 🧪 Teste 5: Validar External DNS

### 5.1. Verificar Logs do External DNS

```bash
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50
```

**✅ Resultado esperado:**
- Logs mostrando criação de DNS records no Route53
- Exemplo:
  ```
  time="..." level=info msg="Applying provider record filter for domains: [example.com. .example.com.]"
  time="..." level=info msg="Desired change: CREATE eks-devopsproject-ingress-xxxxx.example.com A"
  ```

---

### 5.2. Verificar Records no Route53

```bash
# Obter Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query 'HostedZones[0].Id' \
  --output text \
  --profile terraform | cut -d'/' -f3)

# Listar records DNS
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --profile terraform \
  --query 'ResourceRecordSets[?Type==`A` || Type==`CNAME`]' \
  --output table
```

**✅ Resultado esperado:**
- Records DNS criados automaticamente para Ingress resources

---

## 🧪 Teste 6: Validar Prometheus Node Exporter

### 6.1. Verificar Pods do Node Exporter

```bash
kubectl get pods -n prometheus-node-exporter
```

**✅ Resultado esperado:**
- 3 pods `prometheus-node-exporter-xxxxx` em estado `Running`
- 1 pod por node do cluster

---

### 6.2. Verificar Addon EKS

```bash
aws eks describe-addon \
    --cluster-name eks-devopsproject-cluster \
    --addon-name prometheus-node-exporter \
    --profile terraform \
    --query 'addon.[addonName,addonVersion,status]' \
    --output table
```

**✅ Resultado esperado:**
```
--------------------------------------------
|              DescribeAddon               |
+-------------------------+----------------+
|  prometheus-node-exporter |  v1.x.x-eksbuild.x |  ACTIVE  |
+-------------------------+----------------+
```

---

### 6.3. Verificar Métricas Exportadas (Port Forward)

```bash
# Port-forward para um dos node exporters
kubectl port-forward -n prometheus-node-exporter \
  $(kubectl get pod -n prometheus-node-exporter -o name | head -1) \
  9100:9100 &

# Aguardar 2 segundos
sleep 2

# Buscar métricas
curl -s http://localhost:9100/metrics | grep node_cpu_seconds_total | head -5
```

**✅ Resultado esperado:**
```
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
node_cpu_seconds_total{cpu="0",mode="iowait"} 123.45
node_cpu_seconds_total{cpu="0",mode="irq"} 0.12
...
```

**Cleanup:**
```bash
# Matar port-forward
pkill -f "port-forward.*9100"
```

---

## 📊 Checklist de Validação Completa

Use este checklist após deployment completo:

```bash
# ✅ 1. Nodes do cluster
kubectl get nodes | grep Ready | wc -l
# Esperado: 3

# ✅ 2. Pods de sistema rodando
kubectl get pods -A | grep -v Running | grep -v Completed | wc -l
# Esperado: 0 (ou cabeçalho)

# ✅ 3. Karpenter pronto
kubectl get nodepools | grep default-node-pool | grep Ready
kubectl get ec2nodeclasses | grep default | grep Ready

# ✅ 4. Addons EKS ativos
aws eks list-addons --cluster-name eks-devopsproject-cluster --profile terraform | grep -c "aws-ebs-csi-driver\|coredns\|vpc-cni\|prometheus-node-exporter"
# Esperado: 6 (ou verificar lista completa)

# ✅ 5. Prometheus Workspace
aws amp list-workspaces --profile terraform --query 'workspaces[0].status' --output text
# Esperado: ACTIVE

# ✅ 6. Grafana Workspace
aws grafana list-workspaces --profile terraform --query 'workspaces[0].status' --output text
# Esperado: ACTIVE
```

---

## 🔗 Links Relacionados

- **Automação Ansible:** [QUICK-START-ANSIBLE.md](./QUICK-START-ANSIBLE.md)
- **Configuração Manual Grafana:** [CONFIGURACAO-MANUAL-GRAFANA.md](./CONFIGURACAO-MANUAL-GRAFANA.md)
- **README Principal:** [README.md](../README.md)

---

## 💡 Automatizando Estes Testes

Estes testes manuais podem ser automatizados com **Ansible** ou **scripts bash** para CI/CD:

### Exemplo: Script de Validação Completa

```bash
#!/bin/bash
# validate-infrastructure.sh

echo "🔍 Validando infraestrutura EKS..."

# Teste 1: Nodes
NODES=$(kubectl get nodes --no-headers | grep Ready | wc -l)
if [ $NODES -ge 3 ]; then
  echo "✅ Nodes: $NODES nodes prontos"
else
  echo "❌ Nodes: Esperado >=3, encontrado $NODES"
  exit 1
fi

# Teste 2: Pods de sistema
PODS_FAIL=$(kubectl get pods -A | grep -v Running | grep -v Completed | grep -v NAME | wc -l)
if [ $PODS_FAIL -eq 0 ]; then
  echo "✅ Pods: Todos running"
else
  echo "❌ Pods: $PODS_FAIL pods com problemas"
  exit 1
fi

# Teste 3: Karpenter
kubectl get nodepools default-node-pool | grep Ready > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Karpenter: NodePool pronto"
else
  echo "❌ Karpenter: NodePool não está Ready"
  exit 1
fi

echo "🎉 Validação completa com sucesso!"
```

**Uso:**
```bash
chmod +x validate-infrastructure.sh
./validate-infrastructure.sh
```

---

**Desenvolvido com ❤️ para aprendizado de DevOps e Infraestrutura como Código**
