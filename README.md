# ToggleMaster — Fase 4: Observabilidade · OpenTelemetry · APM · Self-Healing

> POSTECH Tech Challenge — Pós-Tech Cloud Architecture and DevOps
> Fase 4: monitoramento open source no Kubernetes, padronização com OpenTelemetry, APM com tracing distribuído, alertas inteligentes e automação de resposta a incidentes.
>
> **Status:** em andamento. Diagrama de arquitetura e relatório em [`_Entregáveis/`](_Entregáveis/).

---

## Visão Geral

ToggleMaster é uma plataforma de **feature flags** com 5 microsserviços, implantada na AWS com EKS. O projeto é **evolutivo e cumulativo**: a Fase 4 é construída sobre a base das fases anteriores.

| Fase | Entrega |
|------|---------|
| 1–2 | Microsserviços conteinerizados e deploy manual no EKS |
| 3 | Terraform (IaC), CI DevSecOps no GitHub Actions e entrega via GitOps com ArgoCD |
| **4** | **Observabilidade total e resposta ativa a incidentes** |

**O problema desta fase:** o `evaluation-service` falhou silenciosamente, o HPA escalou para compensar e a equipe levou 6 horas para ser avisada e mais 4 para achar a causa raiz nos logs espalhados pelos pods.

**O objetivo:** lentidão → ver o **trace**; erro → **logs centralizados**; limite atingido → **incidente no PagerDuty** e aviso no chat; e o sistema tenta se **curar sozinho**.

---

## Status da Fase 4

| Etapa | Descrição | Status |
|-------|-----------|--------|
| 0 | Repositório da Fase 4 a partir da base da Fase 3 | ✅ Concluída |
| — | CI: permissões explícitas do `GITHUB_TOKEN` (repositório novo vem com token só leitura) | ✅ Concluída |
| 1 | Contas gratuitas: New Relic, PagerDuty, Discord | ⏳ Próxima |
| 2 | GitOps da plataforma: ArgoCD versionado + app-of-apps | ⬜ Planejada |
| 3 | Laboratório local de observabilidade (docker-compose) | ⬜ Planejada |
| 4 | Instrumentação OpenTelemetry dos 5 serviços | ⬜ Planejada |
| 5 | Dashboard do Grafana e regras de alerta | ⬜ Planejada |
| 6 | Remediator (self-healing) | ⬜ Planejada |
| 7 | Helm charts e Applications no GitOps | ⬜ Planejada |
| 8–9 | Sessões no EKS: integração, gravação e evidências | ⬜ Planejada |

---

## Arquitetura

O diagrama completo, com o que já está implementado e o que está planejado, está em [`_Entregáveis/togglemaster-arquitetura-fase4.html`](_Entregáveis/togglemaster-arquitetura-fase4.html).

Fluxo de telemetria e resposta (alvo da Fase 4):

```
 Microsserviços (SDK OTel) ──OTLP──▶ ┌──────────────────┐ ──▶ New Relic (traces, service map)
 logs stdout dos pods ───filelog───▶ │  OTel Collector  │ ──▶ Prometheus (métricas)
                                     │   (DaemonSet)    │ ──▶ Loki (logs)
                                     └──────────────────┘
                                                                 │
                                         Grafana (dashboard + alerta: 5xx auth > 5%)
                                                                 │
                         ┌──────────────────────┬────────────────┴───────────┐
                         ▼                      ▼                            ▼
                  PagerDuty (incidente)   Discord (ChatOps)      Remediator (self-healing)
                                                                             │
                                               kubectl rollout restart deployment/auth
```

### Escolhas técnicas (custo zero)

| Componente | Escolha | Por quê |
|------------|---------|---------|
| Métricas + visualização | kube-prometheus-stack (Prometheus + Grafana) | Open source, roda no cluster; dashboards versionados como ConfigMap |
| Logs | Loki (single-binary) | Recebe OTLP nativo do Collector |
| Peça central | OpenTelemetry Collector | Obrigatório no enunciado; padrão CNCF (Alloy avaliado como alternativa) |
| APM | New Relic | Plano gratuito permanente (100 GB/mês, sem cartão) e ingestão OTLP direta |
| Incidentes | PagerDuty (Free) | OpsGenie encerrou novos cadastros em 2025 e será desligado em abr/2027 |
| ChatOps | Discord | Webhook sem aprovação de app; contact point nativo no Grafana |
| Self-healing | Remediator no cluster (RBAC mínimo) | Lambda exige IAM role (bloqueada no Academy); GitHub Action dependeria de credenciais temporárias |

---

## Microsserviços

| Serviço | Linguagem | Porta | Função |
|---------|-----------|-------|--------|
| `auth-service` | Go | 8001 | Criação e validação de API keys |
| `flag-service` | Python | 8002 | CRUD de feature flags |
| `targeting-service` | Python | 8003 | Regras de segmentação de usuários |
| `evaluation-service` | Go | 8004 | Avaliação de flags em tempo real (Redis + eventos no SQS) |
| `analytics-service` | Python | 8005 | Consome eventos do SQS e grava no DynamoDB |

---

## Estrutura do Repositório

```
.
├── _Entregáveis/                   # Relatório (.docx) e diagrama de arquitetura (.html)
├── infra/                          # Terraform
│   ├── backend.tf                  # State remoto no S3 (lock nativo: use_lockfile)
│   ├── main.tf · variables.tf · outputs.tf
│   ├── ecr.tf                      # 5 repositórios ECR
│   └── modules/
│       ├── networking/             # VPC, subnets, IGW, NAT, route tables
│       ├── eks/                    # Cluster EKS + node group (LabRole)
│       └── data-stores/            # 3× RDS PostgreSQL, ElastiCache Redis, DynamoDB, SQS
├── services/                       # auth, evaluation (Go) · flag, targeting, analytics (Python)
├── gitops/
│   ├── argocd/applications.yaml    # Applications do ArgoCD (um por serviço)
│   └── services/<svc>/deployment.yaml
├── scripts/
│   ├── set-github-secrets.sh       # Copia as credenciais do Academy para os secrets do repositório
│   ├── verify.sh                   # Confere os recursos criados na AWS
│   └── check-orphans.sh            # Procura recursos esquecidos após o destroy
└── .github/workflows/
    ├── go-ci.yml · python-ci.yml   # Pipelines reutilizáveis
    └── <svc>-service.yml           # Um gatilho por serviço
```

---

## Infraestrutura (Terraform)

```bash
cd infra/
terraform init
terraform plan
terraform apply      # ~15 min
```

**AWS Academy:** o Terraform não pode criar IAM Roles; a `LabRole` é importada via data source e associada ao cluster e ao node group.

**State remoto:** bucket S3 com lock nativo (`use_lockfile = true`). A Fase 4 usa a chave própria `togglemaster-fase4/terraform.tfstate`.

**Custo:** o ambiente sobe só nas sessões de integração e gravação (crédito Academy de US$ 50, ~US$ 0,40/h). Toda sessão termina com:

```bash
terraform destroy
bash scripts/check-orphans.sh
```

---

## Pipeline CI/CD (GitHub Actions)

Cada serviço tem um gatilho (`<svc>-service.yml`) que chama o pipeline reutilizável da sua linguagem em push e PR para a `main`:

```
build-and-test ┐
               ├─▶ security-scan (GATE) ─▶ docker-build-push ─▶ atualiza tag no gitops/
lint ──────────┘    Trivy SCA + gosec/bandit   Trivy image scan       commit [skip ci]
                    CRITICAL bloqueia          push no ECR só em push na main
```

**Permissões do `GITHUB_TOKEN`:** o pipeline reutilizável roda com `contents: read` por padrão. Só o job `docker-build-push`, que commita a nova tag, pede `contents: write`, e quem chama concede essa permissão explicitamente.

**Secrets necessários** (*Settings → Secrets → Actions*): `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`. As credenciais do Academy expiram a cada sessão; para renová-las, rode `bash scripts/set-github-secrets.sh`.

| Ferramenta | Tipo | Serviços |
|------------|------|----------|
| Trivy (fs) | SCA — dependências | Todos |
| gosec | SAST — Go | auth, evaluation |
| bandit | SAST — Python | flag, targeting, analytics |
| Trivy (image) | Container scan | Todos |

---

## GitOps + ArgoCD

O ArgoCD monitora `gitops/` e sincroniza automaticamente (`automated`, `prune`, `selfHeal`).

> **Estado atual (herdado da Fase 3):** o ArgoCD e as Applications são aplicados manualmente. Na etapa 2 eles passam a ser declarativos (app-of-apps), que é a porta de entrada da stack de observabilidade.

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f gitops/argocd/applications.yaml

# Interface web
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
kubectl port-forward svc/argocd-server -n argocd 8080:443   # https://localhost:8080 (admin)
```

---

## Pré-requisitos Locais

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/) e [AWS CLI](https://aws.amazon.com/cli/) v2
- [Docker](https://www.docker.com/) (laboratório local de observabilidade)
- [GitHub CLI](https://cli.github.com/) (renovação dos secrets)
- Acesso ao cluster: `aws eks update-kubeconfig --region us-east-1 --name <cluster-name>`

---

## Autores

- Emily Marcolino
- Cristiano Alves de Oliveira Schaarschmidt
- Expedito Ferreira da Silva Filho

POSTECH — Pós-Tech Cloud Architecture and DevOps · Fase 4 · 2026
