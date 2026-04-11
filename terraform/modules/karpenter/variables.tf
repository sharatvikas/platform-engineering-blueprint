variable "cluster_name" {
  description = "EKS cluster name — used for resource naming and discovery tags"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA (from eks-cluster module output)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
