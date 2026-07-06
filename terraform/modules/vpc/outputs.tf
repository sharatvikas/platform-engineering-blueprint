output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability zones the subnets were created in"
  value       = local.azs
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ) — EKS nodes and pods"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ) — load balancers and NAT"
  value       = aws_subnet.public[*].id
}

output "intra_subnet_ids" {
  description = "Intra subnet IDs (no internet route — for databases)"
  value       = aws_subnet.intra[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs (one per AZ)"
  value       = aws_route_table.private[*].id
}

output "intra_route_table_id" {
  description = "Intra route table ID (null when intra subnets are disabled)"
  value       = try(aws_route_table.intra[0].id, null)
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (empty when nat_strategy = none)"
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs assigned to NAT gateways — allowlist these for egress"
  value       = aws_eip.nat[*].public_ip
}

output "vpc_endpoint_s3_id" {
  description = "S3 Gateway endpoint ID (null when disabled)"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "vpc_endpoints_security_group_id" {
  description = "Security group attached to Interface endpoints (null when none enabled)"
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
}

output "flow_logs_log_group_name" {
  description = "CloudWatch log group receiving VPC Flow Logs (null when disabled)"
  value       = try(aws_cloudwatch_log_group.flow_logs[0].name, null)
}
