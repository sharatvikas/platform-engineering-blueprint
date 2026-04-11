output "controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller (set as Helm value)"
  value       = aws_iam_role.karpenter.arn
}

output "node_role_arn" {
  description = "IAM role ARN for Karpenter-provisioned nodes"
  value       = aws_iam_role.karpenter_node.arn
}

output "node_instance_profile_name" {
  description = "Instance profile name for Karpenter-provisioned nodes (set in EC2NodeClass)"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "interruption_queue_name" {
  description = "SQS queue name for spot interruption handling (set as Helm value)"
  value       = aws_sqs_queue.interruption.name
}

output "interruption_queue_arn" {
  description = "SQS queue ARN for spot interruption handling"
  value       = aws_sqs_queue.interruption.arn
}
