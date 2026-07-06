# Complete example — exercises every feature of the VPC module.
# Run with: terraform init && terraform plan
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

module "vpc" {
  source = "../.."

  name         = "example-vpc"
  cluster_name = "example-cluster"
  vpc_cidr     = "10.42.0.0/16"
  az_count     = 3

  # Cost-optimized for an example environment; use "per-az" in production
  nat_strategy         = "single"
  create_intra_subnets = true

  enable_flow_logs         = true
  flow_logs_retention_days = 14
  flow_logs_traffic_type   = "REJECT" # only denied traffic, keeps costs low

  enable_s3_endpoint   = true
  enable_ecr_endpoints = true
  enable_sts_endpoint  = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
    Repo        = "platform-engineering-blueprint"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "intra_subnet_ids" {
  value = module.vpc.intra_subnet_ids
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}
