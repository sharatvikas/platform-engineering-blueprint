variable "name" {
  description = "Base name for the EKS cluster (combined with environment to form cluster name)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production, staging, dev)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for worker nodes and control plane ENIs"
  type        = list(string)
}

variable "public_endpoint_enabled" {
  description = "Whether the Kubernetes API server endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint (only used when public_endpoint_enabled = true)"
  type        = list(string)
  default     = []
}

variable "node_groups" {
  description = "Map of managed node group definitions"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string # ON_DEMAND or SPOT
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size_gb   = optional(number, 50)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    system = {
      instance_types = ["m6i.large", "m6a.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      disk_size_gb   = 50
      labels = {
        "role" = "system"
      }
    }
  }
}

variable "cluster_addons" {
  description = "EKS managed addons to install (map of addon_name → version, empty string = latest)"
  type        = map(string)
  default = {
    vpc-cni            = ""
    coredns            = ""
    kube-proxy         = ""
    aws-ebs-csi-driver = ""
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting Kubernetes secrets at rest. If empty, a new key is created."
  type        = string
  default     = ""
}

variable "cluster_log_retention_days" {
  description = "CloudWatch log retention for EKS control plane logs (days)"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
