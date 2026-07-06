# VPC Module

Opinionated 3-tier VPC for EKS-based platforms. Carves a single CIDR into
per-AZ **private** (nodes/pods), **public** (load balancers, NAT), and
**intra** (databases, no internet route) subnets, with EKS/Karpenter
discovery tags, VPC Flow Logs, and cost-saving VPC endpoints built in.

## Subnet layout

For `vpc_cidr = 10.0.0.0/16`, `az_count = 3` the module carves nine `/20`s
(`cidrsubnet(cidr, 4, n)`):

| Tier    | AZ a          | AZ b          | AZ c          | Routes                        |
|---------|---------------|---------------|---------------|-------------------------------|
| private | 10.0.0.0/20   | 10.0.16.0/20  | 10.0.32.0/20  | NAT (per strategy), S3 GW     |
| public  | 10.0.48.0/20  | 10.0.64.0/20  | 10.0.80.0/20  | Internet Gateway              |
| intra   | 10.0.96.0/20  | 10.0.112.0/20 | 10.0.128.0/20 | local only (+ S3 GW endpoint) |

## NAT strategy

`nat_strategy` controls egress cost vs. availability:

| Value    | NAT gateways | Use case                                                        |
|----------|--------------|-----------------------------------------------------------------|
| `per-az` | one per AZ   | Production — AZ-isolated egress, no cross-AZ data charges       |
| `single` | one          | Dev/staging — ~$65/mo saved per extra AZ; AZ loss kills egress  |
| `none`   | zero         | Fully-private clusters — requires ECR/STS/S3 endpoints enabled  |

Private route tables are always created per-AZ, so switching strategies never
recreates subnet associations — only the `aws_route` entries change.

## EKS tagging

- `kubernetes.io/cluster/<cluster_name> = shared` on VPC and all subnets
- `kubernetes.io/role/elb = 1` on public subnets (internet-facing LBs)
- `kubernetes.io/role/internal-elb = 1` on private subnets (internal LBs)
- `karpenter.sh/discovery = <cluster_name>` on private subnets

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name         = "platform-production-vpc"
  cluster_name = "platform-production"
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 3

  nat_strategy         = "per-az" # single | per-az | none
  create_intra_subnets = true

  enable_flow_logs         = true
  flow_logs_retention_days = 90
  flow_logs_traffic_type   = "ALL"

  enable_s3_endpoint   = true
  enable_ecr_endpoints = true
  enable_sts_endpoint  = true

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

See [`examples/complete`](examples/complete/) for a runnable root module.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | — | Name prefix for all VPC resources |
| `cluster_name` | `string` | — | EKS cluster name for discovery tags |
| `vpc_cidr` | `string` | `10.0.0.0/16` | VPC CIDR, `/20` or larger |
| `az_count` | `number` | `3` | AZs to span (2–4) |
| `nat_strategy` | `string` | `per-az` | `per-az` \| `single` \| `none` |
| `create_intra_subnets` | `bool` | `true` | Isolated subnets for databases |
| `enable_flow_logs` | `bool` | `true` | VPC Flow Logs → CloudWatch |
| `flow_logs_retention_days` | `number` | `30` | CloudWatch retention |
| `flow_logs_traffic_type` | `string` | `ALL` | `ACCEPT` \| `REJECT` \| `ALL` |
| `enable_s3_endpoint` | `bool` | `true` | S3 Gateway endpoint (free) |
| `enable_ecr_endpoints` | `bool` | `true` | ECR api+dkr Interface endpoints |
| `enable_sts_endpoint` | `bool` | `true` | STS Interface endpoint (IRSA) |
| `tags` | `map(string)` | `{}` | Applied to every resource |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` / `vpc_cidr` | VPC identifiers |
| `availability_zones` | AZs used |
| `private_subnet_ids` / `public_subnet_ids` / `intra_subnet_ids` | Subnets per tier |
| `private_subnet_cidrs` | Private CIDRs (for security group rules) |
| `public_route_table_id` / `private_route_table_ids` / `intra_route_table_id` | Route tables |
| `nat_gateway_ids` / `nat_public_ips` | NAT gateways and their EIPs |
| `vpc_endpoint_s3_id` / `vpc_endpoints_security_group_id` | Endpoint plumbing |
| `flow_logs_log_group_name` | Flow log destination |
