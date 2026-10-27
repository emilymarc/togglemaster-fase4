# ToggleMaster — Fase 3: IaC · CI/CD · DevSecOps · GitOps

> POSTECH Tech Challenge — Pós-Tech Cloud Architecture and DevOps 
> Fase 3: Infraestrutura como Código, Pipeline DevSecOps e entrega contínua via GitOps
>
> Acesse o [Relatório](https://docs.google.com/document/d/1fgQpNsPGOSZTqEKWE4jljNRQ37ftIUHs/edit) detalhado e 
> [Vídeo](https://youtu.be/TFgtYMbo-XI) explicativo.

---

## Visão Geral

ToggleMaster é uma plataforma de **feature flags** composta por 5 microsserviços, implantada na AWS com EKS. Esta fase automatiza todo o ciclo de vida da infraestrutura e das aplicações usando Terraform, GitHub Actions e ArgoCD.

**Antes (Fase 2):** `kubectl apply` manual, credenciais em texto, infraestrutura recriada no console em dias.  
**Depois (Fase 3):** Se não está no código, não existe. Tudo, feito via Terraform, automatizado e versionado.

---

## Arquitetura

```
┌─ IaC (Terraform) ─────┐     ┌─ CI/CD (GitHub Actions) ──────┐     ┌─ AWS Cloud ─────────────────┐
│                        │     │                                │     │                             │
│  modules/              │     │  Trigger: push/PR → main       │     │  ECR × 5 repos              │
│  ├── networking        │────▶│  ├── build-and-test  ┐         │────▶│                             │
│  ├── eks               │     │  ├── lint             ├ paralelo│     │  EKS Cluster                │
│  ├── rds               │     │  ├── security-scan    ┘         │     │  └── ArgoCD (auto-sync)     │
│  ├── elasticache       │     │  ├── docker-build-push          │     │      └── ns: togglemaster   │
│  ├── dynamo_sqs        │     │  └── update-gitops              │     │          ├── auth (Go)       │
│  └── ecr               │     │                                │     │          ├── flag (Python)   │
│                        │     │  Reusable workflows:            │     │          ├── targeting (Py)  │
│  State: S3 + DynamoDB  │     │  go-ci.yml · python-ci.yml     │     │          ├── evaluation (Go) │
│  IAM: LabRole (data    │     │                                │     │          └── analytics (Py)  │
│        source)         │     │                                │     │                             │
└────────────────────────┘     └────────────────────────────────┘     │  RDS PostgreSQL × 3         │
                                                                       │  ElastiCache Redis          │
                                                                       │  DynamoDB (Analytics)       │
                                                                       │  SQS (event queue)          │
                                                                       └─────────────────────────────┘
```

---

## Microsserviços

| Serviço | Linguagem | Função |
|---------|-----------|--------|
| `auth-service` | Go | Autenticação e emissão de tokens |
| `flag-service` | Python | CRUD de feature flags |
| `targeting-service` | Python | Regras de segmentação de usuários |
| `evaluation-service` | Go | Avaliação de flags em tempo real |
| `analytics-service` | Python | Coleta e análise de eventos |

---

## Estrutura do Repositório

```
.
├── infra/                          # Terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf                  # S3 remote state + DynamoDB lock
│   └── modules/
│       ├── networking/             # VPC, subnets, IGW, route tables
│       ├── eks/                    # Cluster EKS + node groups (LabRole)
│       ├── rds/                    # 3× PostgreSQL
│       ├── elasticache/            # Redis
│       ├── dynamo_sqs/             # DynamoDB + SQS
│       └── ecr/                   # 5 repositórios ECR
│
├── services/
│   ├── auth/                       # Go
│   ├── flag/                       # Python
│   ├── targeting/                  # Python
│   ├── evaluation/                 # Go
│   └── analytics/                  # Python
│
├── gitops/
│   └── services/
│       ├── auth/deployment.yaml
│       ├── flag/deployment.yaml
│       ├── targeting/deployment.yaml
│       ├── evaluation/deployment.yaml
│       └── analytics/deployment.yaml
│
└── .github/
    └── workflows/
        ├── reusable-go-ci.yml      # Pipeline reutilizável para Go
        ├── reusable-python-ci.yml  # Pipeline reutilizável para Python
        ├── auth.yml                # Chama go-ci com service_dir=auth
        ├── flag.yml                # Chama python-ci com service_dir=flag
        ├── targeting.yml
        ├── evaluation.yml
        └── analytics.yml
```

---

## Infraestrutura (Terraform)

### Pré-requisitos

- Terraform >= 1.5
- AWS CLI configurado (`aws configure` ou variáveis de ambiente)
- Bucket S3 e tabela DynamoDB para o state backend já criados

### Deploy

```bash
cd infra/

# Inicializa com o backend remoto
terraform init

# Valida o plano antes de aplicar
terraform plan

# Aplica (~15 min; cria 25+ recursos)
terraform apply
```

### Restrição AWS Academy

O ambiente Academy não permite criar IAM Roles via Terraform. A `LabRole` é importada via **data source**:

```hcl
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
```

Essa role é associada ao cluster EKS e aos node groups.

### State Remoto

```hcl
# infra/backend.tf
terraform {
  backend "s3" {
    bucket         = "<seu-bucket-tfstate>"
    key            = "togglemaster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<sua-tabela-lock>"
  }
}
```

---

## Pipeline CI/CD (GitHub Actions)

### Fluxo por serviço

```
push / PR → main
     │
     ▼
┌─────────────────────────────────────────┐
│  workflow_call → reusable pipeline       │
│                                         │
│  [build-and-test] ──┐                   │
│                      ├── paralelo        │
│  [lint]         ────┘                   │
│         │                               │
│         ▼                               │
│  [security-scan]  ← GATE               │
│   Trivy SCA (deps) + gosec/bandit SAST  │
│   exit-code 1 se CRITICAL encontrado    │
│         │                               │
│         ▼                               │
│  [docker-build-push]                    │
│   build → Trivy image scan → ECR push   │
│   tag: SHA[:7]  |  só em push na main   │
│         │                               │
│         ▼                               │
│  [update-gitops]                        │
│   sed → deployment.yaml (nova tag)      │
│   stefanzweifel/git-auto-commit@v5      │
│   commit [skip ci] → main               │
└─────────────────────────────────────────┘
```

### Segredos necessários

Configure em **Settings → Secrets → Actions** do repositório:

| Secret | Descrição |
|--------|-----------|
| `AWS_ACCESS_KEY_ID` | Chave de acesso AWS |
| `AWS_SECRET_ACCESS_KEY` | Chave secreta AWS |
| `AWS_SESSION_TOKEN` | Token de sessão (obrigatório no Academy) |

### Ferramentas de segurança

| Ferramenta | Tipo | Serviços |
|------------|------|----------|
| Trivy (fs) | SCA — dependências | Todos |
| gosec | SAST — código Go | auth, evaluation |
| bandit | SAST — código Python | flag, targeting, analytics |
| Trivy (image) | Container scan | Todos |

---

## GitOps + ArgoCD

O ArgoCD monitora a pasta `gitops/` e sincroniza automaticamente qualquer mudança no `deployment.yaml` com o cluster EKS.

### Instalar ArgoCD no cluster

```bash
# Instala o ArgoCD no namespace argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguarda os pods subirem
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

### Acessar a interface web

```bash
# 1. Recupera a senha inicial do admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 2. Abre o port-forward (mantém o terminal aberto)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Acessa em **https://localhost:8080** → usuário: `admin`, senha: passo 1.  
O certificado é self-signed — aceita o aviso do browser.

### Configuração de sync

Os Apps ArgoCD são configurados com:

```yaml
syncPolicy:
  automated:
    selfHeal: true    # reverte mudanças manuais no cluster
    prune: true       # remove recursos deletados do gitops
```

---

## Fluxo Completo de Deploy

```
1. Dev faz push em services/<service>/
2. GitHub Actions dispara o pipeline do serviço
3. Build → Lint → Security Scan (GATE) → Docker Build+Push para ECR
4. CI atualiza gitops/services/<service>/deployment.yaml com nova tag SHA
5. ArgoCD detecta a mudança no repositório (polling ~3 min)
6. ArgoCD sincroniza → Kubernetes faz rolling update do pod
```

---

## Desafios Encontrados

| Desafio | Causa | Solução |
|---------|-------|---------|
| Branch protection bloqueando o bot | GH013: CI bot sem permissão de push na main | Settings → Rules → Bypass list → adicionar GitHub Actions bot |
| ECR tag immutability | Mesmo SHA não pode sobrescrever tag existente | `git commit --allow-empty -m "ci: force new pipeline run"` para gerar novo SHA |
| Race condition no GitOps | 5 pipelines simultâneos, só o primeiro push tem sucesso (non-fast-forward) | Disparar os serviços com ~1 min de intervalo; não afeta produção |

---

## Decisões Técnicas

**stefanzweifel/git-auto-commit-action@v5** em vez de git manual no update-gitops: a action cuida de config, add, commit, pull e push em um único step, evitando race conditions e configuração de identidade git no CI.

**permissions: contents: write** no job docker-build-push: necessário para que o GITHUB_TOKEN do bot tenha permissão de push no repositório ao commitar o deployment.yaml.

**Trivy em dois modos**: `fs` no security-scan (varre dependências antes do build) e `image` no docker-build-push (varre as camadas da imagem final, incluindo pacotes do S.O.). São complementares — um não substitui o outro.

**LabRole via data source**: restrição do AWS Academy impede criação de IAM Roles via Terraform. Usar `data "aws_iam_role"` importa a role existente sem tentar criá-la.

---

## Pré-requisitos Locais

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [AWS CLI](https://aws.amazon.com/cli/) v2
- [Docker](https://www.docker.com/)
- Acesso ao cluster: `aws eks update-kubeconfig --region us-east-1 --name <cluster-name>`

---

## Autores
- Emily Marcolino
- Cristiano Alves de Oliveira Schaarschmidt
- Expedito Ferreira da Silva Filho

Por:
POSTECH — Pós-Tech Cloud Architecture and DevOps · Fase 3 · 2026
