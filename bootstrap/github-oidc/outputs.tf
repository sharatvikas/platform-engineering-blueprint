# ─────────────────────────────────────────────────────────────────────────────
# Outputs — each value maps to the exact GitHub Actions secret it feeds.
# The description contains the precise `gh secret set` command to run.
# ─────────────────────────────────────────────────────────────────────────────

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (created or existing). Reference only — not a secret."
  value       = local.oidc_provider_arn
}

# ── terraform-ai-guardian ────────────────────────────────────────────────────

output "AWS_PLAN_ROLE_ARN" {
  description = "gh secret set AWS_PLAN_ROLE_ARN --repo sharatvikas/terraform-ai-guardian --body <value>  (read-only plan/validate + TF state)"
  value       = aws_iam_role.guardian_plan.arn
}

output "TF_AWS_ROLE_ARN" {
  description = "gh secret set TF_AWS_ROLE_ARN --repo sharatvikas/terraform-ai-guardian --body <value>  (same role as AWS_PLAN_ROLE_ARN — read-only plan/validate + TF state)"
  value       = aws_iam_role.guardian_plan.arn
}

output "AWS_DRIFT_ROLE_ARN" {
  description = "gh secret set AWS_DRIFT_ROLE_ARN --repo sharatvikas/terraform-ai-guardian --body <value>  (same role as AWS_PLAN_ROLE_ARN — read-only + TF state; drift detection)"
  value       = aws_iam_role.guardian_plan.arn
}

output "AWS_ORG_READER_ROLE_ARN" {
  description = "gh secret set AWS_ORG_READER_ROLE_ARN --repo sharatvikas/terraform-ai-guardian --body <value>  (org-wide read + AssumeRole into member accounts)"
  value       = aws_iam_role.org_reader.arn
}

# ── platform-engineering-blueprint ───────────────────────────────────────────

output "AWS_TERRAFORM_ROLE_ARN" {
  description = "gh secret set AWS_TERRAFORM_ROLE_ARN --repo sharatvikas/platform-engineering-blueprint --body <value>  (read-only drift detection + TF state; consumed by .github/workflows/drift-detection.yaml)"
  value       = aws_iam_role.platform_drift.arn
}

# ── aws-finops-intelligence ──────────────────────────────────────────────────

output "AWS_ROLE_ARN" {
  description = "gh secret set AWS_ROLE_ARN --repo sharatvikas/aws-finops-intelligence --body <value>  (read-only cost/usage telemetry)"
  value       = aws_iam_role.finops.arn
}

# ── Terraform state backend ──────────────────────────────────────────────────

output "TF_STATE_BUCKET" {
  description = "gh secret set TF_STATE_BUCKET --repo sharatvikas/terraform-ai-guardian --body <value>  (also set on platform-engineering-blueprint if it shares this backend). Name of the S3 remote-state bucket."
  value       = local.state_bucket_name
}

output "tf_state_lock_table" {
  description = "DynamoDB lock table name for the Terraform S3 backend (backend `dynamodb_table` setting). Reference only."
  value       = local.state_lock_table
}
