output "cluster_name" {
  description = "EKS cluster name (used by Karpenter and other modules)"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint URL — used by kubectl and Helm providers"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate — used by kubectl and Helm providers"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Running Kubernetes version"
  value       = aws_eks_cluster.this.version
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — required by Karpenter module and any IRSA roles"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://) — used for IRSA trust policy construction"
  value       = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

output "cluster_security_group_id" {
  description = "Security group ID created by EKS for the cluster (cluster-managed SG)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Additional security group applied to all managed node groups"
  value       = aws_security_group.node.id
}

output "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "IAM role ARN used by managed node groups — pass to Karpenter for node joining"
  value       = aws_iam_role.node.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for Kubernetes secrets encryption"
  value       = local.kms_key_arn
}
