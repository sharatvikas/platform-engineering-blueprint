# platform-engineering-blueprint

> A **production-ready Internal Developer Platform (IDP)** blueprint combining Backstage, ArgoCD, Crossplane, and GitHub Actions into a self-service platform that lets engineers provision infrastructure and deploy services without tickets.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/terraform-1.7+-623CE4.svg)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.28+-326CE5.svg)](https://kubernetes.io)
[![Backstage](https://img.shields.io/badge/backstage-latest-9BF0E1.svg)](https://backstage.io)
[![ArgoCD](https://img.shields.io/badge/argocd-2.10+-orange.svg)](https://argo-cd.readthedocs.io)

---

## What Is This?

Platform Engineering is the discipline of building and operating internal self-service platforms to reduce cognitive load on product engineers. Instead of filing tickets to get an S3 bucket or a new service namespace, engineers fill out a form — and the platform handles everything else.

This blueprint is a fully functional, opinionated IDP you can fork and adapt. It's not a demo — it's battle-tested patterns distilled from running large-scale AWS+K8s platforms.

---

## Platform Components

```
┌────────────────────────────────────────────────────────────────┐
│                    Developer Experience Layer                  │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │           Backstage (Internal Developer Portal)         │  │
│  │  Service Catalog │ Software Templates │ Tech Docs       │  │
│  └──────────────────────────┬──────────────────────────────┘  │
│                             │                                  │
│              ┌──────────────┼────────────────┐                 │
│              │              │                │                 │
│  ┌───────────▼──┐  ┌────────▼──────┐  ┌─────▼─────────────┐  │
│  │   ArgoCD     │  │  Crossplane   │  │   GitHub Actions   │  │
│  │  (GitOps CD) │  │  (Infra CRDs) │  │   (CI Pipelines)  │  │
│  └───────────┬──┘  └────────┬──────┘  └─────┬─────────────┘  │
│              │              │                │                 │
│  ┌───────────▼──────────────▼────────────────▼─────────────┐  │
│  │               Infrastructure Layer                      │  │
│  │   EKS Clusters │ RDS │ S3 │ VPC │ IAM │ Route53         │  │
│  └─────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## What Engineers Can Self-Serve

### Via Backstage Software Templates (Scaffolder)
- **New microservice** — Git repo + CI pipeline + ArgoCD app + namespace + RBAC, all in one form
- **New database** — RDS or Aurora instance via Crossplane CR, with auto-generated K8s secret
- **New S3 bucket** — With lifecycle policies, encryption, and access policy baked in
- **New environment** — Staging environment clone with namespace isolation
- **Observability** — Grafana dashboard + Prometheus alerts scaffolded from service template

### Via Crossplane (Infrastructure as CRDs)
```yaml
# Engineer files this — no Terraform needed
apiVersion: platform.io/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: payments-db
  namespace: production
spec:
  size: medium          # small | medium | large (maps to RDS instance class)
  version: "15"
  multiAZ: true
  backupRetentionDays: 14
  team: payments
```

The platform provisions RDS, creates a K8s secret with credentials, and configures automated backups — in ~5 minutes.

---

## Repository Structure

```
platform-engineering-blueprint/
├── platform/
│   ├── backstage/
│   │   ├── app-config.yaml         # Backstage configuration
│   │   ├── catalog/                # Software catalog entities
│   │   └── templates/              # Scaffolder templates
│   │       ├── microservice/
│   │       ├── database/
│   │       └── s3-bucket/
│   ├── argocd/
│   │   ├── apps/                   # ArgoCD Application CRs
│   │   ├── projects/               # ArgoCD Project boundaries
│   │   └── app-of-apps.yaml        # Root app
│   ├── crossplane/
│   │   ├── compositions/           # XRD Compositions (the infra logic)
│   │   ├── xrds/                   # Custom Resource Definitions
│   │   └── providers/              # Provider configs (AWS, GCP)
│   └── gitops/
│       ├── clusters/               # Per-cluster Kustomize overlays
│       │   ├── production/
│       │   └── staging/
│       └── namespaces/             # Namespace + RBAC manifests
├── terraform/
│   ├── modules/
│   │   ├── eks-cluster/            # EKS module with addons
│   │   ├── vpc/                    # VPC with Transit Gateway
│   │   └── platform-foundation/   # Installs ArgoCD, Crossplane, cert-manager
│   └── environments/
│       ├── production/
│       └── staging/
├── docs/
│   ├── GOLDEN_PATH.md             # The happy path for new services
│   ├── ARCHITECTURE.md
│   └── RUNBOOK_PLATFORM.md
└── .github/
    └── workflows/
        ├── validate-manifests.yaml
        ├── terraform-plan.yaml
        └── backstage-build.yaml
```

---

## Getting Started

### Bootstrap a new platform from scratch

```bash
# 1. Bootstrap AWS infrastructure
cd terraform/environments/production
terraform init && terraform apply

# 2. Platform foundation installs ArgoCD, Crossplane into the cluster automatically

# 3. Apply the App-of-Apps — ArgoCD takes over from here
kubectl apply -f platform/argocd/app-of-apps.yaml

# 4. Deploy Backstage
helm upgrade --install backstage platform/backstage/ \
  --namespace backstage --create-namespace

# Platform is live. Point engineers at https://portal.your-org.com
```

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| GitOps engine | ArgoCD over Flux | Better UI, stronger multi-tenancy, wider adoption |
| Infra abstraction | Crossplane over CDK/Pulumi | K8s-native, no separate control plane |
| Portal | Backstage | Industry standard, plugin ecosystem |
| IaC | Terraform | Team familiarity, provider maturity |
| Service mesh | Istio | mTLS, traffic management, observability |
| Secrets | External Secrets Operator → AWS Secrets Manager | No secrets in Git, ever |

---

## Roadmap

- [x] EKS cluster Terraform module
- [x] ArgoCD App-of-Apps pattern
- [x] Crossplane AWS provider compositions
- [x] Backstage software catalog
- [ ] Backstage Scaffolder templates
- [ ] Crossplane PostgreSQL composition
- [ ] Internal RBAC model documentation
- [ ] Backstage TechDocs pipeline
- [ ] Cost allocation tagging enforcement
- [ ] Policy-as-code with OPA Gatekeeper

---

## License

MIT — see [LICENSE](LICENSE).
