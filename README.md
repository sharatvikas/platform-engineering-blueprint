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
├── terraform/
│   ├── modules/
│   │   ├── vpc/                    # 3-AZ VPC: public/private/intra, NAT strategy,
│   │   │   │                       #   flow logs, S3/ECR/STS endpoints, EKS tags
│   │   │   └── examples/complete/  # Runnable example invocation
│   │   ├── eks-cluster/            # EKS + IRSA/OIDC, KMS, managed node groups, addons
│   │   └── karpenter/              # Karpenter IAM + interruption queue
│   └── envs/
│       └── production/             # Root module: VPC → EKS → Karpenter → ArgoCD
├── gitops/
│   ├── argocd/
│   │   ├── app-of-apps.yaml        # Root Application (applied by Terraform)
│   │   ├── projects/               # AppProjects: platform + tenants (RBAC, sync windows)
│   │   └── apps/                   # Child Applications, ordered by sync wave:
│   │       ├── platform-projects.yaml     # wave -5  AppProjects first
│   │       ├── cert-manager.yaml          # wave  0
│   │       ├── ingress-nginx.yaml         # wave  1
│   │       ├── kube-prometheus-stack.yaml # wave  2  monitoring
│   │       ├── crossplane.yaml            # wave  2  crossplane core
│   │       ├── crossplane-config.yaml     # wave  3  providers + XRDs + compositions
│   │       └── backstage.yaml             # wave  4  developer portal last
│   ├── crossplane/
│   │   ├── providers/              # provider-aws family, IRSA runtime config, ProviderConfig
│   │   ├── compositions/           # XRD+Composition pairs: rds, s3, vpc, eks-cluster
│   │   └── claims/                 # Example claims dev teams commit (not synced)
│   ├── karpenter/                  # NodePools
│   └── workflows/                  # Promotion workflows
├── backstage/
│   ├── catalog-info.yaml           # Software catalog entities
│   └── templates/                  # Scaffolder templates (microservice, rds,
│                                   #   s3, data-pipeline, sre-service)
└── .github/workflows/              # Drift detection
```

---

## Getting Started

### Bootstrap order

One `terraform apply` bootstraps everything; ArgoCD sync waves handle the rest:

```bash
# 1. AWS foundation — VPC (3-AZ, per-AZ NAT, flow logs, VPC endpoints),
#    EKS (IRSA, KMS-encrypted secrets), Karpenter, then ArgoCD via Helm,
#    and finally the root App-of-Apps manifest.
cd terraform/envs/production
terraform init && terraform apply

# 2. ArgoCD reconciles gitops/argocd/apps/ in sync-wave order:
#    -5 AppProjects → 0 cert-manager → 1 ingress → 2 monitoring + crossplane
#    → 3 crossplane providers/XRDs/compositions → 4 backstage
#    No further kubectl or helm commands needed.

# 3. Verify
kubectl -n argocd get applications   # all Synced/Healthy
kubectl get providers                # crossplane provider-aws family Installed

# Platform is live. Point engineers at https://backstage.internal.example.com
```

### Provision infrastructure as a dev team

```bash
# Commit a claim to your repo (see gitops/crossplane/claims/ for annotated examples)
kubectl apply -f gitops/crossplane/claims/postgres-claim.yaml

# ~5 min later: Multi-AZ encrypted RDS, credentials in your namespace
kubectl -n team-payments get secret payments-db-conn
```

### Network layout

`terraform/modules/vpc` carves one CIDR into three tiers per AZ — see the
[module README](terraform/modules/vpc/README.md) for the full input/output
reference and NAT cost trade-offs (`per-az` | `single` | `none`).

```
             10.0.0.0/16
   ┌────────────┼─────────────┐
   AZ-a         AZ-b          AZ-c
   private /20  private /20   private /20   ← EKS nodes  (NAT egress, S3/ECR/STS endpoints)
   public  /20  public  /20   public  /20   ← NLB/ALB, NAT gateways (IGW)
   intra   /20  intra   /20   intra   /20   ← RDS/ElastiCache (no internet route)
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
- [x] VPC Terraform module (NAT strategies, flow logs, VPC endpoints)
- [x] ArgoCD App-of-Apps pattern with sync waves + AppProject RBAC
- [x] Crossplane AWS provider install (IRSA) + compositions
- [x] Crossplane PostgreSQL composition + self-service claims
- [x] Backstage software catalog
- [x] Backstage Scaffolder templates
- [ ] Internal RBAC model documentation
- [ ] Backstage TechDocs pipeline
- [ ] Cost allocation tagging enforcement
- [ ] Policy-as-code with OPA Gatekeeper

---

## License

MIT — see [LICENSE](LICENSE).
