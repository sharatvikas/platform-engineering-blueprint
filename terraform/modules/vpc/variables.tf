variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used for subnet discovery tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix of /20 or larger (module carves 9 /4-offset subnets)."
  }
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4. EKS requires at least 2 AZs; the subnet layout supports at most 4."
  }
}

variable "nat_strategy" {
  description = <<-EOT
    NAT gateway strategy:
      * per-az — one NAT gateway per AZ (HA, no cross-AZ data charges; production default)
      * single — one NAT gateway shared by all AZs (cost saving for non-prod; AZ failure takes out egress)
      * none   — no NAT gateways (fully private clusters; requires VPC endpoints for ECR/STS/S3)
  EOT
  type        = string
  default     = "per-az"

  validation {
    condition     = contains(["per-az", "single", "none"], var.nat_strategy)
    error_message = "nat_strategy must be one of: per-az, single, none."
  }
}

variable "create_intra_subnets" {
  description = "Create isolated intra subnets for databases and internal services"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch retention for VPC Flow Logs, in days"
  type        = number
  default     = 30

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.flow_logs_retention_days
    )
    error_message = "flow_logs_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "flow_logs_traffic_type" {
  description = "Traffic type to capture in flow logs: ACCEPT, REJECT, or ALL"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "enable_s3_endpoint" {
  description = "Create S3 Gateway endpoint (free, reduces NAT costs)"
  type        = bool
  default     = true
}

variable "enable_ecr_endpoints" {
  description = "Create ECR Interface endpoints (reduces NAT costs for EKS image pulls; required when nat_strategy=none)"
  type        = bool
  default     = true
}

variable "enable_sts_endpoint" {
  description = "Create STS Interface endpoint (IRSA token exchange without NAT; required when nat_strategy=none)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
