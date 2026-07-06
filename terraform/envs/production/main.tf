# Production environment — composes VPC + EKS + Karpenter modules
# This is the root module that platform teams actually apply
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }

  backend "s3" {
    bucket         = "sovrn-terraform-state"
    key            = "production/platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Team        = "platform"
      Repo        = "platform-engineering-blueprint"
    }
  }
}

locals {
  cluster_name = "sovrn-production"
  aws_region   = var.aws_region
}

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  name         = "${local.cluster_name}-vpc"
  cluster_name = local.cluster_name
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 3

  nat_strategy         = "per-az" # HA NAT for production
  create_intra_subnets = true

  enable_flow_logs         = true
  flow_logs_retention_days = 90 # compliance retention for production

  enable_s3_endpoint   = true
  enable_ecr_endpoints = true
  enable_sts_endpoint  = true

  tags = {
    Environment = "production"
  }
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks-cluster"

  name               = "sovrn" # cluster name becomes sovrn-production
  environment        = "production"
  kubernetes_version = "1.29"
  subnet_ids         = module.vpc.private_subnet_ids
  vpc_id             = module.vpc.vpc_id

  node_groups = {
    system = {
      instance_types = ["m6i.xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      labels = {
        "node-role" = "system"
      }
      taints = []
    }
  }

  # Karpenter handles application workloads — node group only for system pods
  tags = {
    Environment = "production"
  }
}

# ── Karpenter ─────────────────────────────────────────────────────────────────
module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn

  tags = {
    Environment = "production"
  }

  depends_on = [module.eks]
}

# ── Kubernetes / Helm providers ──────────────────────────────────────────────
# Exec-based auth: tokens are minted per-operation via `aws eks get-token`,
# so they never expire mid-apply and never land in state.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "0.36.1"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.controller_role_arn
  }
  set {
    name  = "settings.clusterName"
    value = local.cluster_name
  }
  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.interruption_queue_name
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  depends_on = [module.karpenter]
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  namespace        = "argocd"
  create_namespace = true
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "6.7.3"

  values = [
    yamlencode({
      server = {
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["argocd.internal.sovrn.com"]
        }
      }
      configs = {
        params = {
          "server.insecure" = true # TLS terminated at ingress
        }
      }
    })
  ]

  depends_on = [helm_release.karpenter]
}

# Bootstrap the App-of-Apps after ArgoCD is ready
resource "kubernetes_manifest" "platform_root_app" {
  manifest   = yamldecode(file("${path.module}/../../../gitops/argocd/app-of-apps.yaml"))
  depends_on = [helm_release.argocd]
}
