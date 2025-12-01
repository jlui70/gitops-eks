# ✅ Checklist Pré-Commit para GitHub

## 🔍 Verificações de Segurança

### 1. Arquivos Sensíveis Removidos
- [ ] Nenhum arquivo `.tfstate` no repositório
- [ ] Nenhum arquivo `.tfvars` com valores reais
- [ ] Nenhum diretório `.terraform/` commitado
- [ ] Nenhum arquivo de backup (`.backup`, `.bkp`)

### 2. Dados Sensíveis Substituídos
- [x] `02-eks-cluster/locals.tf` → Username IAM substituído por `<YOUR_IAM_USER>`
- [x] `02-eks-cluster/locals.tf` → SSO Role ID substituído por `xxxxx`
- [ ] Account ID `620958830769` substituído por placeholders (se necessário)

### 3. Documentação Privada Movida
- [x] Todos os docs estão em `docs/` (local only)
- [x] `README.md` é o único doc público

### 4. Estrutura do Projeto
```
lab-eks-terraform-ansible/
├── .gitignore              ✅ Configurado
├── .gitattributes          ✅ Criado
├── README.md               ✅ Público (principal doc)
├── SECURITY.md             ✅ Política de segurança
├── CHECKLIST-PRE-COMMIT.md ✅ Este arquivo
├── destroy-all.sh          ✅ Script público
├── rebuild-all.sh          ✅ Script público
├── 00-backend/             ✅ Terraform stacks
├── 01-networking/          ✅ Terraform stacks
├── 02-eks-cluster/         ✅ Terraform stacks
├── 03-karpenter-auto-scaling/ ✅ Terraform stacks
├── 04-security/            ✅ Terraform stacks
├── 05-monitoring/          ✅ Terraform stacks
├── ansible/                ✅ Playbooks + Roles
├── scripts/                ✅ Scripts auxiliares
└── docs/                   ⚠️  LOCAL ONLY (não commitar)
```

### 5. Arquivos Ignorados pelo Git

Execute para verificar:
```bash
git status --ignored
```

**Deve mostrar ignorado:**
- `.terraform/` (em cada stack)
- `*.tfstate`
- `*.tfstate.backup`
- `*.tfvars` (se houver)

### 6. Validação Final

**Antes de `git push`:**

```bash
# 1. Verificar arquivos que serão commitados
git status

# 2. Verificar se há secrets expostos (manual)
grep -r "620958830769" . --exclude-dir=.git --exclude-dir=docs
grep -r "devops-lui" . --exclude-dir=.git --exclude-dir=docs
grep -r "a08e3792465d3f04" . --exclude-dir=.git --exclude-dir=docs

# 3. Verificar .gitignore está ativo
cat .gitignore

# 4. Listar todos os arquivos rastreados
git ls-files

# 5. Verificar se .tfstate NÃO está rastreado
git ls-files | grep tfstate
# (resultado deve ser VAZIO)
```

### 7. Comandos de Commit Seguros

```bash
# 1. Adicionar arquivos específicos (NUNCA use git add .)
git add README.md
git add SECURITY.md
git add CHECKLIST-PRE-COMMIT.md
git add .gitignore
git add .gitattributes
git add destroy-all.sh
git add rebuild-all.sh
git add 00-backend/
git add 01-networking/
git add 02-eks-cluster/
git add 03-karpenter-auto-scaling/
git add 04-security/
git add 05-monitoring/
git add ansible/
git add scripts/

# 2. Verificar o que será commitado
git status

# 3. Commitar
git commit -m "feat: Initial commit - EKS Terraform + Ansible automation"

# 4. Push para GitHub
git push origin main
```

### 8. Pós-Commit - Validação GitHub

Após o push, verifique no GitHub:

1. **Arquivos visíveis:**
   - [ ] `README.md` está renderizado corretamente
   - [ ] `SECURITY.md` está acessível
   - [ ] Estrutura de pastas está correta

2. **Arquivos NÃO visíveis:**
   - [ ] `docs/` **NÃO** aparece no repositório ✅
   - [ ] `.tfstate` **NÃO** aparece no repositório ✅
   - [ ] `.terraform/` **NÃO** aparece no repositório ✅

3. **Buscar por vazamentos:**
   - [ ] Buscar por `620958830769` (não deve aparecer)
   - [ ] Buscar por `devops-lui` (não deve aparecer)
   - [ ] Buscar por `a08e3792465d3f04` (não deve aparecer)

---

## ⚠️ SE ENCONTRAR DADOS SENSÍVEIS APÓS COMMIT

**NÃO ENTRE EM PÂNICO!** Siga este processo:

### Opção 1: Remover arquivo do último commit
```bash
git rm --cached <arquivo-sensivel>
git commit --amend -m "fix: Remove sensitive file"
git push --force
```

### Opção 2: Reescrever histórico (se já fez vários commits)
```bash
# Usar BFG Repo Cleaner
java -jar bfg.jar --delete-files <arquivo-sensivel>
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

### Opção 3: Deletar e recriar repositório (último recurso)
```bash
# Deletar repositório no GitHub
# Remover .git local
rm -rf .git
# Limpar arquivos sensíveis
# Reiniciar git
git init
git add <arquivos-seguros>
git commit -m "Initial commit"
git remote add origin <novo-repo>
git push -u origin main
```

---

## 🎯 Resumo Rápido

**ANTES de `git push`:**
1. ✅ Verifique `.gitignore` está configurado
2. ✅ Remova dados sensíveis (`locals.tf` já corrigido)
3. ✅ Confirme que `docs/` não será commitado
4. ✅ Execute `git status` e valide arquivos
5. ✅ Execute `git ls-files | grep tfstate` → deve estar vazio
6. ✅ Faça commit seletivo (nunca `git add .`)

**APÓS `git push`:**
1. ✅ Acesse GitHub e valide estrutura
2. ✅ Busque por Account ID / Username no código
3. ✅ Confirme `docs/` não está visível

---

**🔒 Lembre-se:** Segurança primeiro! Melhor perder 10 minutos validando do que expor credenciais.
