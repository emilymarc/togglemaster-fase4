# ToggleMaster — Fase 4: Observabilidade · OpenTelemetry · APM · Self-Healing

> POSTECH Tech Challenge — Pós-Tech Cloud Architecture and DevOps
> Fase 4: monitoramento open source no Kubernetes, padronização com OpenTelemetry, APM com tracing distribuído, alertas inteligentes e automação de resposta a incidentes.
>
> Diagrama de arquitetura e relatório em [`_Entregáveis/`](_Entregáveis/).

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

## Como usar (passo a passo)

Ordem de uma sessão completa, do zero até os dashboards:

1. **Credenciais:** inicie o lab do AWS Academy e copie as credenciais para o terminal (`aws configure` ou variáveis `AWS_*`).
2. **Infraestrutura:** `cd infra && terraform init && terraform apply` (~15 min).
3. **Acesso ao cluster:** `aws eks update-kubeconfig --region us-east-1 --name <cluster-name>`.
4. **Secrets do cluster** (nunca vão para o Git): `togglemaster-secrets` (namespace `togglemaster`), `newrelic-license` e `grafana-alerting` (namespace `observability`). Ver [Observabilidade](#observabilidade).
5. **GitOps:** `bash scripts/install-argocd.sh`. O ArgoCD instala os 5 serviços e toda a stack de observabilidade a partir de `gitops/`.
6. **Explorar:** ArgoCD (`localhost:8080`), Grafana (`localhost:3000`) e New Relic (traces e service map). Comandos de acesso nas seções abaixo.
7. **Encerrar:** `terraform destroy` e `bash scripts/check-orphans.sh`.

---

## Arquitetura

O diagrama completo está em [`_Entregáveis/togglemaster-arquitetura-fase4.html`](_Entregáveis/togglemaster-arquitetura-fase4.html).

Fluxo de telemetria e resposta a incidentes:

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
                  PagerDuty (incidente)   Discord (ChatOps)   GitHub Action (self-healing)
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
| Self-healing | GitHub Action disparada via webhook (`repository_dispatch`) | Opção do enunciado; o log de cada execução fica na aba Actions. Lambda exige IAM role, bloqueada no Academy |

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
│   ├── root-app.yaml               # Root app (app-of-apps), aplicada uma única vez
│   ├── apps/                       # Uma Application por componente (serviços, Prometheus, Loki, Collector, storage, dashboards)
│   ├── platform/values/            # values dos Helm charts
│   ├── platform/storage/           # StorageClass ebs-sc (discos EBS gp3)
│   ├── platform/dashboards/        # Dashboards do Grafana como ConfigMap
│   └── services/<svc>/deployment.yaml
├── scripts/
│   ├── install-argocd.sh           # Instala o ArgoCD (versão fixa) e aplica a root app
│   ├── set-github-secrets.sh       # Copia as credenciais do Academy para o environment "aws academy"
│   ├── verify.sh                   # Confere os recursos criados na AWS
│   └── check-orphans.sh            # Procura recursos esquecidos após o destroy
└── .github/workflows/
    ├── go-ci.yml · python-ci.yml   # Pipelines reutilizáveis
    ├── <svc>-service.yml           # Um gatilho por serviço
    ├── secret-scan.yml             # Varredura de segredos (Trivy) no repositório inteiro
    └── self-healing.yml            # Resposta automática a incidentes (repository_dispatch)
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

**Driver EBS CSI:** o módulo `eks` instala o addon `aws-ebs-csi-driver`, que cria os discos pedidos pelos volumes do Kubernetes (ex.: Loki). Esses discos são criados pelo Kubernetes, não pelo Terraform: o `check-orphans.sh` aponta os que sobrarem após o `destroy`.

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

O ArgoCD usa o padrão **app-of-apps**: a `root` (`gitops/root-app.yaml`) observa `gitops/apps/` e cria as demais Applications. Para colocar algo novo no cluster, basta criar um arquivo em `gitops/apps/` e fazer commit.

| Application | O que instala | Namespace |
|---|---|---|
| auth, flag, targeting, evaluation, analytics | Os 5 microsserviços (`gitops/services/`) | togglemaster |
| kube-prometheus-stack | Prometheus, Grafana, node-exporter, kube-state-metrics (chart 92.17.0) | observability |
| loki | Loki em modo SingleBinary, com disco EBS (chart 6.55.0) | observability |
| opentelemetry-collector | OTel Collector em modo DaemonSet (chart 0.178.2) | observability |
| platform-storage | StorageClass `ebs-sc` (gp3) | — (cluster) |
| platform-dashboards | Dashboard "ToggleMaster · Visão geral" (ConfigMap lido pelo sidecar do Grafana) | observability |

```bash
# Instala o ArgoCD (versão fixa no script) e aplica a root app
bash scripts/install-argocd.sh

# Interface web
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
kubectl port-forward svc/argocd-server -n argocd 8080:443   # https://localhost:8080 (admin)
```

---

## Observabilidade

### OpenTelemetry Collector (peça central)

Os serviços enviam traces e métricas só para o Collector (`opentelemetry-collector.observability:4317`, OTLP gRPC). O Collector também lê os logs dos contêineres direto dos nós (preset `logsCollection`) e marca cada dado com namespace, pod e deployment (preset `kubernetesAttributes`).

| Sinal | Destino | Exporter |
|---|---|---|
| Traces | New Relic | `otlp/newrelic` |
| Métricas | Prometheus (remote write) e New Relic | `prometheusremotewrite`, `otlp/newrelic` |
| Logs | Loki | `otlphttp/loki` |

A license key do New Relic fica num Secret do cluster, nunca no Git:

```bash
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create secret generic newrelic-license --from-literal=license-key=<NEW_RELIC_LICENSE_KEY>
```

### Instrumentação dos serviços

| Serviço | Tipo | Como |
|---|---|---|
| flag, targeting, analytics (Python) | Automática | `opentelemetry-distro` + `opentelemetry-bootstrap -a install` no Dockerfile; o contêiner sobe com `opentelemetry-instrument gunicorn ...` |
| auth, evaluation (Go) | Manual | `telemetry.go` cria TracerProvider/MeterProvider (OTLP gRPC); `otelhttp.NewHandler` no servidor e `otelhttp.NewTransport` no cliente HTTP |
| evaluation → analytics (SQS) | Propagação manual | O evaluation grava o `traceparent` nos `MessageAttributes` da mensagem (span *producer*); o analytics lê e continua o mesmo trace (span *consumer*) |

As variáveis `OTEL_SERVICE_NAME` e `OTEL_EXPORTER_OTLP_ENDPOINT` ficam nos `deployment.yaml` de cada serviço.

### Dashboard como código

`gitops/platform/dashboards/togglemaster-dashboard.yaml` é um ConfigMap com o label `grafana_dashboard: "1"`; o sidecar do Grafana o carrega automaticamente. Painéis: CPU e memória por nó e por pod, requisições por segundo por serviço, taxa de 5xx do auth e logs ao vivo do namespace `togglemaster` (com busca).

```bash
kubectl -n observability get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80   # http://localhost:3000 (admin)
```

### Alertas e self-healing

As regras, os contact points e a política de notificação ficam nos values do Grafana (`grafana.alerting`), versionados como o resto da plataforma.

| Peça | Configuração |
|---|---|
| Regra | `auth-service: erros 5xx acima de 5%`, avaliada a cada 1 min, dispara após 2 min acima do limite |
| Contact point `togglemaster-oncall` | PagerDuty (Events API v2), Discord (`#alertas`) e webhook para a API do GitHub |
| Self-healing | `.github/workflows/self-healing.yml`: recebe o `repository_dispatch` (`grafana-alert`), conecta ao EKS e executa `kubectl rollout restart` no deployment da label `service` do alerta |

As chaves dos três destinos ficam num Secret, lido pelo Grafana como variáveis de ambiente:

```bash
kubectl -n observability create secret generic grafana-alerting \
  --from-literal=PAGERDUTY_INTEGRATION_KEY='<integration key do PagerDuty>' \
  --from-literal=DISCORD_WEBHOOK_URL='<URL do webhook do Discord>' \
  --from-literal=GITHUB_DISPATCH_TOKEN='<fine-grained token: Contents read/write neste repositório>'
kubectl -n observability rollout restart deployment kube-prometheus-stack-grafana
```

O workflow usa as credenciais do environment `aws academy`: renove-as com `bash scripts/set-github-secrets.sh` a cada sessão. Para testar sem esperar o alerta: aba **Actions → self-healing → Run workflow**.

---

## Pré-requisitos Locais

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/) e [AWS CLI](https://aws.amazon.com/cli/) v2
- [Docker](https://www.docker.com/) (build e teste local das imagens)
- [GitHub CLI](https://cli.github.com/) (renovação dos secrets)
- Acesso ao cluster: `aws eks update-kubeconfig --region us-east-1 --name <cluster-name>`

---

## Autores

- Emily Marcolino
- Cristiano Alves de Oliveira Schaarschmidt
- Expedito Ferreira da Silva Filho

POSTECH — Pós-Tech Cloud Architecture and DevOps · Fase 4 · 2026
