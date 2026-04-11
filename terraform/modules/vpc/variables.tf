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
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost saving for non-prod environments)"
  type        = bool
  default     = false
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

variable "enable_s3_endpoint" {
  description = "Create S3 Gateway endpoint (free, reduces NAT costs)"
  type        = bool
  default     = true
}

variable "enable_ecr_endpoints" {
  description = "Create ECR Interface endpoints (reduces NAT costs for EKS image pulls)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
